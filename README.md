# AI Usage Bar

Application de barre de menus macOS qui affiche la consommation de **Claude Code** et **Codex** :

- fenêtre de 5 h et quota hebdomadaire, en jauges colorées (vert / orange / rouge) ou en texte ;
- tokens consommés sur 5 h, aujourd'hui et sur 7 jours ;
- projection de l'heure à laquelle le quota sera atteint au rythme actuel ;
- historique du jour, notifications aux seuils et à la réinitialisation ;
- masquage automatique d'un outil sans fenêtre en cours.

Requiert macOS 13 ou plus récent.

## Installation

1. Télécharge **AIUsageBar.dmg** depuis la [dernière release](https://github.com/RomainDick/ai-usage-bar/releases/latest), ouvre-le et glisse **AIUsageBar** sur **Applications**.
2. Ouvre l'app. La première fois, macOS la bloque car elle n'est pas notarisée par Apple :
   - **macOS 15 et plus** : Réglages Système › Confidentialité et sécurité, puis **Ouvrir quand même** en bas de la page ;
   - **macOS 13 et 14** : clic droit sur l'app › Ouvrir, puis **Ouvrir**.
3. Au premier lancement, l'app propose de se ranger dans Applications si elle n'y est pas, puis d'installer le hook Claude Code. Relance ensuite tes sessions Claude Code.

Le hook se retire ou se réinstalle dans les réglages de l'app (roue crantée), qui proposent aussi **Désinstaller AI Usage Bar** : hook retiré, `statusLine` précédente restaurée, données supprimées et app mise à la corbeille.

### En une commande

Sans blocage macOS, car un fichier téléchargé avec `curl` n'est pas mis en quarantaine :

```sh
curl -fsSL https://raw.githubusercontent.com/RomainDick/ai-usage-bar/main/install.sh | sh
```

Désinstallation équivalente :

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

Le script met à jour la version, crée le tag et le pousse. GitHub Actions construit alors un binaire universel (Apple Silicon et Intel) et publie `AIUsageBar.dmg` et `AIUsageBar.zip`, avec leurs sommes de contrôle, dans les releases.

## Limites

L'app est signée ad hoc et n'est pas notarisée par Apple : macOS demande une autorisation manuelle à la première ouverture d'une app téléchargée depuis le navigateur (voir Installation).
