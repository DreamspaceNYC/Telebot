import os, asyncio, tempfile, subprocess, requests
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from aiogram import Bot, Dispatcher, types
from aiogram.enums import ParseMode

TELEGRAM_TOKEN = os.environ["TELEGRAM_TOKEN"]
WEBHOOK_SECRET = TELEGRAM_TOKEN
APP_URL = os.environ.get("APP_URL", "")
PORT = int(os.environ.get("PORT", "8080"))

bot = Bot(token=TELEGRAM_TOKEN, parse_mode=ParseMode.HTML)
dp = Dispatcher()
app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "ok"}

async def save_file(file_id: str, suffix: str) -> str:
    f = await bot.get_file(file_id)
    fd, path = tempfile.mkstemp(suffix=suffix); os.close(fd)
    url = f"https://api.telegram.org/file/bot{TELEGRAM_TOKEN}/{f.file_path}"
    with requests.get(url, stream=True) as r, open(path, "wb") as out:
        r.raise_for_status()
        for chunk in r.iter_content(1<<14): out.write(chunk)
    return path

def transcode_to_wav(src: str) -> str:
    dst = Path(src).with_suffix(".wav")
    subprocess.check_call(["ffmpeg","-y","-i",src,"-ar","16000","-ac","1",str(dst)])
    return str(dst)

@dp.message()
async def handle_message(message: types.Message):
    if message.voice:
        src = await save_file(message.voice.file_id, ".ogg")
        wav = transcode_to_wav(src)
        await message.reply("📝 Transcoding done. (Hook Whisper here) -> " + os.path.basename(wav))
        return
    await message.reply(f"👋 Echo: {message.text or 'no text'}")

@app.post(f"/webhook/{{secret}}")
async def telegram_webhook(secret: str, request: Request):
    if secret != WEBHOOK_SECRET:
        raise HTTPException(status_code=403, detail="forbidden")
    update = types.Update.model_validate(await request.json(), strict=False)
    await dp.feed_update(bot, update)
    return JSONResponse({"ok": True})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=False)
