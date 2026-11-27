# AI Usage Bar

Application de barre de menus macOS qui affiche la consommation de **Claude Code** et **Codex** :

- fenêtre de 5 h et quota hebdomadaire, en jauges colorées (vert / orange / rouge) ou en texte ;
- tokens consommés sur 5 h, aujourd'hui et sur 7 jours ;
- projection de l'heure à laquelle le quota sera atteint au rythme actuel ;
- historique du jour, notifications aux seuils et à la réinitialisation ;
- masquage automatique d'un outil sans fenêtre en cours.

Requiert macOS 13 ou plus récent.

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/RomainDick/ai-usage-bar/main/install.sh | sh
```

Le script télécharge la dernière release, vérifie sa somme de contrôle, installe l'app dans `~/Applications`, ajoute le hook `statusLine` de Claude Code et lance l'app. Relance ensuite une session Claude Code.

## Désinstallation

```sh
curl -fsSL https://raw.githubusercontent.com/RomainDick/ai-usage-bar/main/uninstall.sh | sh
```

## Fonctionnement

- **Claude Code** : le quota n'est exposé que dans l'entrée JSON de la `statusLine`. L'installation remplace la `statusLine` par `AIUsageBar --statusline`, qui enregistre un relevé dans `~/Library/Application Support/ai-usage-bar/` puis affiche l'ancienne `statusLine` si tu en avais une (elle est conservée et chaînée, et `~/.claude/settings.json` est sauvegardé dans `settings.json.ai-usage-bar.bak`). Le quota Claude n'est donc mis à jour que pendant une session Claude Code.
- **Codex** : le quota et les tokens sont lus dans `~/.codex/sessions`.
- Aucune donnée ne quitte la machine.

## Compiler depuis les sources

Requiert les outils de développement Apple (`xcode-select --install`).

```sh
git clone https://github.com/RomainDick/ai-usage-bar.git
cd ai-usage-bar
./install.sh
```

## Publier une version

```sh
./scripts/release.sh 0.3.0
```

Le script met à jour la version, crée le tag et le pousse. GitHub Actions construit alors un binaire universel (Apple Silicon et Intel) et publie `AIUsageBar.zip` avec sa somme de contrôle dans les releases.

## Limites

L'app est signée ad hoc et n'est pas notarisée par Apple. L'installation par le script fonctionne car un fichier téléchargé avec `curl` n'est pas mis en quarantaine ; un zip téléchargé depuis le navigateur sera bloqué par Gatekeeper au premier lancement.
