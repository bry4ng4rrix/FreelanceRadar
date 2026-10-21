class CollectorError(Exception):
    """Échec de collecte. Le message est destiné à l'historique : jamais de secret dedans."""


class TransientCollectorError(CollectorError):
    """Erreur réseau ou serveur temporaire : une nouvelle tentative a du sens."""


class SourceBlockedError(CollectorError):
    """La plateforme refuse l'accès (401/403/429). Ne jamais tenter de contourner."""


class UnsafeUrlError(CollectorError):
    """URL refusée par la protection SSRF."""


class UnsupportedConnectorError(CollectorError):
    """Aucun connecteur implémenté pour ce type de source."""
