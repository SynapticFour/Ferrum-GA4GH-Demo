//! Docker executor via bollard.
//! GA4GH demo: optional volume binds (WES work dir, docker.sock) and compose network attachment.

use crate::error::{Result, TesError};
use crate::executor::TaskExecutor;
use crate::types::{CreateTaskRequest, TaskState};
use async_trait::async_trait;
use bollard::container::{Config, CreateContainerOptions, StartContainerOptions};
use bollard::models::{ContainerStateStatusEnum, HostConfig};
use bollard::Docker;

pub struct DockerExecutor {
    docker: Docker,
}

impl DockerExecutor {
    pub fn new(docker: Docker) -> Self {
        Self { docker }
    }

    pub fn connect_default() -> std::result::Result<Self, bollard::errors::Error> {
        let docker = Docker::connect_with_local_defaults()?;
        Ok(Self::new(docker))
    }

    fn collect_binds(request: &CreateTaskRequest) -> Vec<String> {
        let mut binds = Vec::new();
        if let Ok(extra) = std::env::var("FERRUM_TES_EXTRA_BINDS") {
            for p in extra.split(',') {
                let p = p.trim();
                if !p.is_empty() {
                    binds.push(p.to_string());
                }
            }
        }
        if let Some(vols) = &request.volumes {
            for v in vols {
                if let (Some(h), Some(c)) = (
                    v.get("hostPath").and_then(|x| x.as_str()),
                    v.get("containerPath").and_then(|x| x.as_str()),
                ) {
                    binds.push(format!("{}:{}", h, c));
                }
            }
        }
        binds
    }
}

#[async_trait]
impl TaskExecutor for DockerExecutor {
    fn name(&self) -> &'static str {
        "docker"
    }

    async fn run(&self, task_id: &str, request: &CreateTaskRequest) -> Result<Option<String>> {
        if request.executors.is_empty() {
            return Err(TesError::Validation("executors required".into()));
        }
        let exec = &request.executors[0];
        let name = format!("tes-{}", task_id);
        let binds = Self::collect_binds(request);
        // Cromwell images set ENTRYPOINT to `java -jar cromwell.jar`. If we only set Cmd to
        // `["sh","-lc", script]`, Docker runs `java ... sh -lc script` (unknown arg `sh`).
        // Override entrypoint and pass the script as Cmd so the image CMD is not appended.
        let mut entrypoint: Option<Vec<String>> = None;
        let mut cmd: Option<Vec<String>> = None;
        let shell_bin = exec.command.first().map(|s| s.as_str());
        let is_shell = matches!(
            shell_bin,
            Some("sh" | "bash" | "/bin/sh" | "/bin/bash")
        );
        if exec.command.len() == 3
            && is_shell
            && (exec.command[1] == "-lc" || exec.command[1] == "-c")
        {
            entrypoint = Some(vec![exec.command[0].clone(), exec.command[1].clone()]);
            cmd = Some(vec![exec.command[2].clone()]);
        } else if !exec.command.is_empty() {
            cmd = Some(exec.command.clone());
        }
        let network_mode = std::env::var("FERRUM_TES_DOCKER_NETWORK")
            .ok()
            .filter(|s| !s.is_empty());
        let extra_hosts = std::env::var("FERRUM_TES_EXTRA_HOSTS")
            .ok()
            .map(|s| {
                s.split(',')
                    .map(|x| x.trim().to_string())
                    .filter(|x| !x.is_empty())
                    .collect::<Vec<_>>()
            })
            .filter(|v| !v.is_empty());
        let host_config = HostConfig {
            binds: if binds.is_empty() {
                None
            } else {
                Some(binds)
            },
            network_mode,
            extra_hosts,
            ..Default::default()
        };
        let config = Config {
            image: Some(exec.image.clone()),
            entrypoint,
            cmd,
            env: exec.env.as_ref().map(|m| {
                m.iter()
                    .map(|(k, v)| format!("{}={}", k, v))
                    .collect::<Vec<_>>()
            }),
            host_config: Some(host_config),
            ..Default::default()
        };
        let platform = std::env::var("FERRUM_TES_DOCKER_PLATFORM")
            .ok()
            .filter(|s| !s.trim().is_empty());
        let opts = CreateContainerOptions { name, platform };
        let create = self
            .docker
            .create_container(Some(opts), config)
            .await
            .map_err(|e| TesError::Executor(e.to_string()))?;
        let id = create.id.clone();
        self.docker
            .start_container(&id, None::<StartContainerOptions<String>>)
            .await
            .map_err(|e| TesError::Executor(e.to_string()))?;
        Ok(Some(id))
    }

    async fn cancel(&self, _task_id: &str, external_id: Option<&str>) -> Result<()> {
        if let Some(id) = external_id {
            let _ = self.docker.stop_container(id, None).await;
        }
        Ok(())
    }

    async fn poll_state(&self, _task_id: &str, external_id: Option<&str>) -> Result<TaskState> {
        let Some(id) = external_id else {
            return Ok(TaskState::Unknown);
        };
        let inspect = self
            .docker
            .inspect_container(id, None)
            .await
            .map_err(|e| TesError::Executor(e.to_string()))?;
        let status = inspect.state.as_ref().and_then(|s| s.status.clone());
        match status {
            Some(ContainerStateStatusEnum::RUNNING) => Ok(TaskState::Running),
            Some(ContainerStateStatusEnum::EXITED) => {
                let exit = inspect
                    .state
                    .as_ref()
                    .and_then(|s| s.exit_code)
                    .unwrap_or(1);
                Ok(if exit == 0 {
                    TaskState::Complete
                } else {
                    TaskState::ExecutorError
                })
            }
            _ => Ok(TaskState::Unknown),
        }
    }
}
