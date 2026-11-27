# AI Quota Meter

Application de barre de menus macOS qui affiche la consommation de **Claude Code** et **Codex** :

- fenêtre de 5 h et quota hebdomadaire, en jauges colorées (vert / orange / rouge) ou en texte ;
- tokens consommés sur 5 h, aujourd'hui et sur 7 jours ;
- projection de l'heure à laquelle le quota sera atteint au rythme actuel ;
- historique du jour, notifications aux seuils et à la réinitialisation ;
- masquage automatique d'un outil sans fenêtre en cours.

Requiert macOS 13 ou plus récent.

## Installation

1. Télécharge **AIQuotaMeter.dmg** depuis la [dernière release](https://github.com/RomainDick/ai-quota-meter/releases/latest), ouvre-le et glisse **AIQuotaMeter** sur **Applications**.
2. Ouvre l'app. La première fois, macOS la bloque car elle n'est pas notarisée par Apple :
   - **macOS 15 et plus** : Réglages Système › Confidentialité et sécurité, puis **Ouvrir quand même** en bas de la page ;
   - **macOS 13 et 14** : clic droit sur l'app › Ouvrir, puis **Ouvrir**.
3. Au premier lancement, l'app propose de se ranger dans Applications si elle n'y est pas, puis d'installer le hook Claude Code. Relance ensuite tes sessions Claude Code.

Le hook se retire ou se réinstalle dans les réglages de l'app (roue crantée), qui proposent aussi **Désinstaller AI Quota Meter** : hook retiré, `statusLine` précédente restaurée, données supprimées et app mise à la corbeille.

### En une commande

Sans blocage macOS, car un fichier téléchargé avec `curl` n'est pas mis en quarantaine :

```sh
curl -fsSL https://raw.githubusercontent.com/RomainDick/ai-quota-meter/main/install.sh | sh
```

Désinstallation équivalente :

```sh
curl -fsSL https://raw.githubusercontent.com/RomainDick/ai-quota-meter/main/uninstall.sh | sh
```

## Mises à jour

Une fois par jour, l'app consulte la dernière release GitHub. Si une version plus récente existe, le menu affiche **Version X disponible** et une notification part, une seule fois par version. **Mettre à jour** télécharge l'archive, vérifie sa somme de contrôle, remplace l'app sur place et la relance : aucun blocage macOS, car le téléchargement n'est pas mis en quarantaine.

La recherche automatique se désactive dans les réglages, qui permettent aussi de la lancer à la main. En ligne de commande : `~/Applications/AIQuotaMeter.app/Contents/MacOS/AIQuotaMeter --update`.

Venant d'**AI Usage Bar** (ancien nom, 0.3.0 et avant) : installe la nouvelle version, l'ancienne app est mise à la corbeille au premier lancement et le hook Claude Code est repointé automatiquement. Les réglages et l'historique sont conservés.

## Fonctionnement

- **Claude Code** : le quota n'est exposé que dans l'entrée JSON de la `statusLine`. L'installation remplace la `statusLine` par `AIQuotaMeter --statusline`, qui enregistre un relevé dans `~/Library/Application Support/ai-usage-bar/` puis affiche l'ancienne `statusLine` si tu en avais une (elle est conservée et chaînée, et `~/.claude/settings.json` est sauvegardé dans `settings.json.ai-usage-bar.bak`). Le quota Claude n'est donc mis à jour que pendant une session Claude Code.
- **Codex** : le quota et les tokens sont lus dans `~/.codex/sessions`.
- Aucune donnée de consommation ne quitte la machine. Seule la recherche de mise à jour contacte GitHub, sans rien envoyer d'autre que la requête.

## Compiler depuis les sources

Requiert les outils de développement Apple (`xcode-select --install`).

```sh
git clone https://github.com/RomainDick/ai-quota-meter.git
cd ai-quota-meter
./install.sh
```

## Publier une version

```sh
./scripts/release.sh 0.4.0
```

Le script met à jour la version, crée le tag et le pousse. GitHub Actions construit alors un binaire universel (Apple Silicon et Intel) et publie `AIQuotaMeter.dmg` et `AIQuotaMeter.zip`, avec leurs sommes de contrôle, dans les releases.

## Limites

L'app est signée ad hoc et n'est pas notarisée par Apple : macOS demande une autorisation manuelle à la première ouverture d'une app téléchargée depuis le navigateur (voir Installation).
