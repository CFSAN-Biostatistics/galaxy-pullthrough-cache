# lib/galaxy/tool_util/deps/container_resolvers/mirror.py
from typing import Container as TypingContainer, Optional
from . import ContainerResolver
from ..requirements import ContainerDescription

class MirrorResolver(ContainerResolver):
    resolver_type = "mirror"

    def __init__(self, app_info, **kwds):
        super().__init__(app_info, **kwds)
        self.source_host: str = kwds.get("source_host", "quay.io")
        self.target_prefix: Optional[str] = kwds.get("target_prefix")

    def resolve(
        self,
        enabled_container_types: TypingContainer[str],
        tool_info,
        **kwds,
    ) -> Optional[ContainerDescription]:
        if not self.target_prefix:
            return None
        for desc in getattr(tool_info, "container_descriptions", []) or []:
            ctype = desc.type or "docker"
            ident = (desc.identifier or "")
            if ident.startswith("docker://"):
                ident = ident[len("docker://"):]
            if ctype == "docker" and ident.startswith(self.source_host + "/"):
                rewritten = f"{self.target_prefix}/{ident.split('/', 1)[1]}"
                out = ContainerDescription(rewritten, type="docker", shell=desc.shell)
                if self._container_type_enabled(out, enabled_container_types):
                    return out
        return None
