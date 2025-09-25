# main.py
import re
import time
from pathlib import Path
from typing import List

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from moviepy.editor import VideoFileClip, concatenate_videoclips

app = FastAPI()

# ----------------------------------------------------------------------
# Paths & Catalogue
# ----------------------------------------------------------------------
BASE_PATH = Path("video")  # directory containing video files

video_names_blender = [
    "0.mp4", "1.mp4", "2.mp4", "3.mp4", "4.mp4", "5.mp4", "6.mp4", "7.mp4", "8.mp4", "9.mp4",
    "A.mp4", "After.mp4", "Again.mp4", "Against.mp4", "Age.mp4", "All.mp4", "Alone.mp4",
    "Also.mp4", "And.mp4", "Ask.mp4", "At.mp4", "B.mp4", "Be.mp4", "Beautiful.mp4",
    "Before.mp4", "Best.mp4", "Better.mp4", "Busy.mp4", "But.mp4", "Bye.mp4", "C.mp4",
    "Can.mp4", "Cannot.mp4", "Change.mp4", "College.mp4", "Come.mp4", "Computer.mp4",
    "D.mp4", "Day.mp4", "Distance.mp4", "Do.mp4", "Do Not.mp4", "Does Not.mp4",
    "E.mp4", "Eat.mp4", "Engineer.mp4", "F.mp4", "Fight.mp4", "Finish.mp4", "From.mp4",
    "G.mp4", "Glitter.mp4", "Go.mp4", "God.mp4", "Gold.mp4", "Good.mp4", "Great.mp4",
    "H.mp4", "Hand.mp4", "Hands.mp4", "Happy.mp4", "Hello.mp4", "Help.mp4", "Her.mp4",
    "Here.mp4", "His.mp4", "Home.mp4", "Homepage.mp4", "How.mp4", "I.mp4", "Invent.mp4",
    "It.mp4", "J.mp4", "K.mp4", "Keep.mp4", "L.mp4", "Language.mp4", "Laugh.mp4",
    "Learn.mp4", "M.mp4", "ME.mp4", "More.mp4", "My.mp4", "N.mp4", "Name.mp4",
    "Next.mp4", "Not.mp4", "Now.mp4", "O.mp4", "Of.mp4", "On.mp4", "Our.mp4", "Out.mp4",
    "P.mp4", "Pretty.mp4", "Q.mp4", "R.mp4", "Right.mp4", "S.mp4", "Sad.mp4", "Safe.mp4",
    "See.mp4", "Self.mp4", "Sign.mp4", "Sing.mp4", "So.mp4", "Sound.mp4", "Stay.mp4",
    "Study.mp4", "T.mp4", "Talk.mp4", "Television.mp4", "Thank.mp4", "Thank You.mp4",
    "That.mp4", "They.mp4", "This.mp4", "Those.mp4", "Time.mp4", "To.mp4", "Type.mp4",
    "U.mp4", "Us.mp4", "V.mp4", "W.mp4", "Walk.mp4", "Wash.mp4", "Way.mp4", "We.mp4",
    "Welcome.mp4", "What.mp4", "When.mp4", "Where.mp4", "Which.mp4", "Who.mp4",
    "Whole.mp4", "Whose.mp4", "Why.mp4", "Will.mp4", "With.mp4", "Without.mp4",
    "Words.mp4", "Work.mp4", "World.mp4", "Wrong.mp4", "X.mp4", "Y.mp4", "You.mp4",
    "Your.mp4", "Yourself.mp4", "Z.mp4"
]

# Map lowercase -> filename with correct case/spaces
video_map = {name.rsplit(".", 1)[0].lower(): name for name in video_names_blender}
video_name_set = set(video_map.keys())

# Stopwords
STOP_WORDS = {
    'am', 'are', 'been', 'being', 'an', 'but', 'or', 'so',
    'does', 'did', 'would', 'shall', 'should', 'may',
    'might', 'must', 'were'
}


class VideoRequest(BaseModel):
    text: str


# ----------------------------------------------------------------------
# Word → Video sequence (greedy matching)
# ----------------------------------------------------------------------
def get_video_filenames_for_word(word: str) -> List[str]:
    word = word.lower()
    pos, result = 0, []

    while pos < len(word):
        for end in range(len(word), pos, -1):
            sub = word[pos:end]
            if sub in video_name_set:
                result.append(video_map[sub])
                pos = end
                break
        else:
            # no match → fallback to single char
            ch = word[pos]
            if ch in video_name_set:
                result.append(video_map[ch])
            pos += 1

    return result


# ----------------------------------------------------------------------
# Merge videos safely
# ----------------------------------------------------------------------
def merge_videos(video_paths: List[Path], output_path: Path):
    clips = []
    try:
        for path in video_paths:
            if not path.exists():
                raise HTTPException(404, f"Video not found: {path.name}")
            clips.append(VideoFileClip(str(path)))

        if not clips:
            raise HTTPException(404, "No clips to merge.")

        final_clip = concatenate_videoclips(clips, method="compose")
        final_clip.write_videofile(
            str(output_path),
            codec="libx264",
            audio_codec="aac",
            preset="veryfast",
            threads=4,
            verbose=False,
            logger=None
        )
    finally:
        for c in clips:
            c.close()
        if "final_clip" in locals():
            final_clip.close()


# ----------------------------------------------------------------------
# API Endpoint
# ----------------------------------------------------------------------
@app.post("/generate_video")
async def generate_video(req: VideoRequest):
    text = (req.text or "").strip().lower()
    if not text:
        raise HTTPException(400, "Input text is empty.")

    # Clean and split
    cleaned = re.sub(r"[^a-z0-9\s]", " ", text)
    words = [w for w in cleaned.split() if w and w not in STOP_WORDS]

    if not words:
        raise HTTPException(400, "No valid words after cleaning.")

    # Build filename sequence
    filename_sequence: List[str] = []
    for w in words:
        filename_sequence.extend(get_video_filenames_for_word(w))

    if not filename_sequence:
        raise HTTPException(404, "No matching videos found.")

    video_paths = [BASE_PATH / fname for fname in filename_sequence]
    missing = [p for p in video_paths if not p.exists()]
    if missing:
        raise HTTPException(404, f"Missing video files: {[m.name for m in missing]}")

    output_path = Path(f"merged_{int(time.time() * 1000)}.mp4")

    try:
        merge_videos(video_paths, output_path)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Failed to merge videos: {e}")

    # Stream and delete
    def iterfile(path: Path):
        try:
            with path.open("rb") as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b""):
                    yield chunk
        finally:
            path.unlink(missing_ok=True)

    return StreamingResponse(
        iterfile(output_path),
        media_type="video/mp4",
        headers={"Content-Disposition": "attachment; filename=merged_video.mp4"}
    )


# ----------------------------------------------------------------------
# Run Locally
# ----------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
