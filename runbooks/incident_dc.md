# Incident datacenter complet

## Symptômes
- Perte totale de services sur un DC
- Traefik injoignable

## Actions immédiates
1. Basculer le trafic vers le DC restant (DNS/GSLB).
2. Vérifier l'état du cluster DB (quorum).

## Validation
- Accès Passbolt via le DC restant
- Quorum Galera maintenu
