# Render Keep-Alive Pinger — 1 minute setup

Ye repo aapki Render free services ko sone se rokta hai (15 min inactivity = 50 sec cold start).

## Enable karna (sirf 30 second):

1. Is page par `ping.yml` file kholo (upar file list me hai)
2. Upar right me **copy** icon dabao (ya file kholke "Raw" → sab select → copy)
3. Repo ke home par jao → **Add file** → **Create new file**
4. File name likho: `.github/workflows/ping.yml`  (exact — slash ke saath)
5. Box me paste karo → neeche **Commit changes**
6. Ho gaya! Ab har 5 minute GitHub khud dono services ko ping karega.

## Kaam kar raha hai ya nahi — check kaise:

Repo → **Actions** tab → "Render Keep-Alive" → last run green hona chahiye.
Log me dikhega:
```
https://utility-duniya-bot.onrender.com/ping -> HTTP 200
https://utility-api-vu83.onrender.com/health -> HTTP 200
```

## Note:
- Isme **koi secret nahi** hai — sirf public URLs.
- GitHub free minutes: **public repo me unlimited** — isliye ye free hai.
