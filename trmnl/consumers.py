import base64
import json
import shutil
import tempfile
import time

from channels.generic.websocket import AsyncWebsocketConsumer
from playwright.async_api import async_playwright
from PIL import Image

from byos_django import settings


class PreviewConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        if not self.scope["user"].is_superuser:
            await self.close(reason="Unauthorized")
        self.pw_manager = async_playwright()
        self.pw = await self.pw_manager.__aenter__()
        if settings.PW_SERVER:
            self.browser = await self.pw.firefox.connect(ws_endpoint=settings.PW_SERVER)
        else:
            self.browser = await self.pw.firefox.launch(
                headless=True,
                args=["--window-size=800,480", "--disable-web-security"],
            )
        self.page = await self.browser.new_page()
        await self.page.set_viewport_size({"width": 800, "height": 480})
        await self.accept()

    async def disconnect(self, close_code):
        await self.page.close()
        self.page = None
        await self.browser.close()
        self.pw = None
        await self.pw_manager.__aexit__()
        pass

    async def receive(self, text_data=None, bytes_data=None) -> None:
        text_data_json = json.loads(text_data)
        await self.send(
            text_data=json.dumps(await self.generate(text_data_json.get("html", None)))
        )

    async def generate(self, html):
        start_time = time.time()
        if not html:
            return {"content": ""}

        # get random file name
        folder = tempfile.mkdtemp()

        await self.page.set_content(html)
        await self.page.evaluate(
            'document.getElementsByTagName("html")[0].style.overflow = "hidden";'
            'document.getElementsByTagName("body")[0].style.overflow = "hidden";'
        )
        await self.page.screenshot(path=f"/{folder}/screen.png")

        # Replaces the previous wand/ImageMagick pipeline (posterize +
        # composite against a pattern:gray50 map + quantize) with Pillow's
        # own 1-bit conversion, which already Floyd-Steinberg dithers by
        # default - the gray50 composite step had no visible effect on an
        # opaque screenshot with no alpha channel (compositing a fully
        # opaque image "over" anything just replaces it), so this should
        # be visually equivalent, not just similar.
        with Image.open(f"/{folder}/screen.png") as img:
            img = img.convert("L").convert("1")
            img.save(f"/{folder}/screen.bmp", format="BMP")

        with open(f"/{folder}/screen.bmp", "rb") as f:
            # base64
            screen = f"data:image/bmp;base64,{base64.b64encode(f.read()).decode()}"

        # clean up
        shutil.rmtree(folder, ignore_errors=True)

        return (
            {
                "content": screen,
                "render_time": time.time() - start_time,
            },
        )
