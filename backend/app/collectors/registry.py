"""Registre des connecteurs : ajouter un type de source = ajouter une entrée ici."""

from app.collectors.base import Collector
from app.collectors.errors import UnsupportedConnectorError
from app.collectors.rss import RssCollector

_COLLECTORS: dict[str, Collector] = {
    "rss": RssCollector(),
}


def supported_target_types() -> frozenset[str]:
    return frozenset(_COLLECTORS)


def get_collector(target_type: str) -> Collector:
    try:
        return _COLLECTORS[target_type]
    except KeyError:
        raise UnsupportedConnectorError(
            f"Aucun connecteur disponible pour le type « {target_type} »."
        ) from None
