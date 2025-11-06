# GitHub Pages Deployment Setup

This document explains how to set up GitHub Pages deployment for Super Tux War.

## One-Time Setup

### 1. Enable GitHub Pages

1. Go to your repository: https://github.com/tuxx/super-tux-war
2. Click **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions**
4. Save the settings

### 2. Create a Tag to Trigger Deployment

The workflow triggers automatically when you push a tag:

```bash
# Create and push a tag
git tag v0.1.0
git push origin v0.1.0
```

### 3. Access Your Game

After the workflow completes (check the Actions tab), your game will be available at:
**https://tuxx.github.io/super-tux-war/**

## How It Works

- The workflow runs when you push any tag
- It downloads Godot 4.5.1 and export templates
- Builds the web export
- Adds SharedArrayBuffer support (coi-serviceworker)
- Deploys to GitHub Pages

## Updating the Game

Just create and push a new tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

## Troubleshooting

### Build Fails
- Check the Actions tab for error logs
- Ensure export_presets.cfg is committed
- Verify Godot version matches (4.5.1)

### Game Doesn't Load
- Check browser console for errors
- Ensure SharedArrayBuffer is enabled (coi-serviceworker handles this)
- Try a hard refresh (Ctrl+Shift+R)

### Wrong Godot Version
Update the `GODOT_VERSION` in `.github/workflows/deploy-web.yml`
