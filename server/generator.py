import torch
import os
import scipy.io.wavfile
import uuid
from diffusers import AutoPipelineForText2Image, AudioLDM2Pipeline
from bark import SAMPLE_RATE, generate_audio, preload_models
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# --- Model Config ---
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DTYPE = torch.float16 if torch.cuda.is_available() else torch.float32

app = FastAPI(title="Soviet Coffee Machine Media Server")

# Global variables for models to enable lazy loading
sd_pipe = None
ldm_pipe = None
bark_preloaded = False

def get_sdxl():
    global sd_pipe
    if sd_pipe is None:
        print("Loading SDXL-Turbo (Optimized for 12GB VRAM)...")
        # SDXL-Turbo fits natively in 12GB in fp16
        sd_pipe = AutoPipelineForText2Image.from_pretrained(
            "stabilityai/sdxl-turbo", 
            torch_dtype=torch.float16, 
            variant="fp16"
        )
        sd_pipe.to(DEVICE)
    return sd_pipe

def get_ldm():
    global ldm_pipe
    if ldm_pipe is None:
        print("Loading AudioLDM2...")
        ldm_pipe = AudioLDM2Pipeline.from_pretrained("cvssp/audioldm2", torch_dtype=DTYPE)
        ldm_pipe.to(DEVICE)
    return ldm_pipe

def ensure_bark():
    global bark_preloaded
    if not bark_preloaded:
        print("Loading Bark...")
        preload_models()
        bark_preloaded = True

class PromptRequest(BaseModel):
    image_prompt: str = ""
    tts_prompt: str = ""
    sfx_prompt: str = ""

@app.post("/generate")
async def generate_all(req: PromptRequest):
    results = {}
    job_id = str(uuid.uuid4())[:8]
    os.makedirs(f"output/{job_id}", exist_ok=True)

    # 1. Generate Image (SDXL-Turbo, 32 steps)
    if req.image_prompt:
        pipe = get_sdxl()
        # Extreme quality mode (32 steps)
        image = pipe(
            prompt=req.image_prompt,
            num_inference_steps=32,
            guidance_scale=0.0,
            height=768,
            width=1024
        ).images[0]
        img_path = f"output/{job_id}/image.png"
        image.save(img_path)
        results["image_url"] = img_path

    # 2. Generate SFX (LDM2, 64 iterations)
    if req.sfx_prompt:
        pipe = get_ldm()
        clean_sfx = req.sfx_prompt.replace("SFX: ", "").split("(")[0].strip()
        audio = pipe(clean_sfx, num_inference_steps=64).audios[0]
        sfx_path = f"output/{job_id}/sfx.wav"
        scipy.io.wavfile.write(sfx_path, rate=16000, data=audio)
        results["sfx_url"] = sfx_path

    # 3. Generate Speech (Bark)
    if req.tts_prompt:
        ensure_bark()
        audio_array = generate_audio(req.tts_prompt)
        tts_path = f"output/{job_id}/tts.wav"
        scipy.io.wavfile.write(tts_path, SAMPLE_RATE, audio_array)
        results["tts_url"] = tts_path

    return results

if __name__ == "__main__":
    import uvicorn
    print(f"Starting generator on {DEVICE}...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
