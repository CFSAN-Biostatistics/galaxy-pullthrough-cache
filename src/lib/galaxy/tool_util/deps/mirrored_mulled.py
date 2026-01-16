# lib/galaxy/tool_util/deps/container_resolvers/mirrored_mulled.py
from typing import Container as TypingContainer, Optional, List
from . import ContainerResolver
from ..requirements import ContainerDescription, DEFAULT_CONTAINER_SHELL
from ..conda_util import CondaTarget

def _targets_to_mulled_name(namespace: str, targets: List[CondaTarget], hash_func: str, session=None) -> Optional[str]:
    # Lazy import avoids doing any network or large imports at module import time
    from ..mulled.util import mulled_tags_for, split_tag, v1_image_name, v2_image_name

    if not targets:
        return None
    if len(targets) == 1:
        t = targets[0]
        tags = mulled_tags_for(namespace, t.package, session=session)
        if not tags:
            return None
        for tag in tags:
            version = split_tag(tag)[0] if "--" in tag else tag
            if t.version and version == t.version:
                return f"{t.package}:{tag}"
        return f"{t.package}:{tags[0]}"
    base = v2_image_name(targets) if hash_func == "v2" else v1_image_name(targets)
    repo, tag_prefix = base.split(":", 1) if ":" in base else (base, None)
    tags = mulled_tags_for(namespace, repo, tag_prefix=tag_prefix, session=session)
    if not tags:
        return None
    tag = tags[0]
    return (f"{base.split(':',1)[0]}:{tag}") if ":" in base else f"{base}:{tag}"

class MirroredMulledDockerContainerResolver(ContainerResolver):
    resolver_type = "mirrored_mulled"
    shell = DEFAULT_CONTAINER_SHELL

    def __init__(self, app_info, namespace: str = "biocontainers", hash_func: str = "v2", **kwds):
        super().__init__(app_info, **kwds)
        self.namespace = namespace
        self.hash_func = hash_func
        self.target_prefix: Optional[str] = kwds.get("target_prefix")

    def resolve(
        self,
        enabled_container_types: TypingContainer[str],
        tool_info,
        session=None,
        **kwds,
    ) -> Optional[ContainerDescription]:
        if tool_info.requires_galaxy_python_environment or "docker" not in enabled_container_types:
            return None
        if not self.target_prefix:
            return None
        # Lazy import (avoid any mulled import at module import time)
        from .mulled import mulled_targets
        targets = mulled_targets(tool_info)
        if not targets:
            return None
        name = _targets_to_mulled_name(self.namespace, targets, self.hash_func, session=session)
        if not name:
            return None
        return ContainerDescription(f"{self.target_prefix}/{self.namespace}/{name}", type="docker", shell=self.shell)
