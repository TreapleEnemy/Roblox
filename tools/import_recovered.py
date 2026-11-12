"""One-time import of the intact recovered modules into GladeSlayer/src (+ replays history edit #283 on Animator)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REC = os.path.join(ROOT, "..", ".temp", "gs", "GladeSlayer_recovered", "src_recovered")

COPIES = {
    "shared/Config.luau": "src/shared/Config.luau",
    "shared/Animator.luau": "src/shared/Animator.luau",
    "server/Main.server.luau": "src/server/Main.server.luau",
}

ANIM_OLD = "\t-- NPC\n\tHammer = {"
ANIM_NEW = """\t-- Передвижение мобов (Effects включает клип, пока моб движется): слизень пружинит, Страж шагает.
\tSlimeBounce = {
\t\tkey(0.16, "Quad", "Out", { Body = { 0, 0, 0, P = V3(0, -0.15, 0) } }, V3(1.12, 0.86, 1.12)),
\t\tkey(0.2, "Quad", "Out", { Body = { -6, 0, 0, P = V3(0, 0.55, 0) } }, V3(0.92, 1.12, 0.92)),
\t\tkey(0.18, "Quad", "In", {}, V3(1, 1, 1)),
\t},
\tGuardianWalk = {
\t\tkey(0.32, "Sine", "InOut", {
\t\t\tTorso = { 0, 4, 0 }, RightLeg = { 24, 0, 0 }, LeftLeg = { -24, 0, 0 },
\t\t\tRightArm = { -16, 0, 6 }, LeftArm = { 16, 0, -6 },
\t\t}),
\t\tkey(0.32, "Sine", "InOut", {
\t\t\tTorso = { 0, -4, 0 }, RightLeg = { -24, 0, 0 }, LeftLeg = { 24, 0, 0 },
\t\t\tRightArm = { 16, 0, 6 }, LeftArm = { -16, 0, -6 },
\t\t}),
\t},
\t-- NPC
\tHammer = {"""

HEALTH = """-- GladeSlayer: пустой скрипт с именем Health в StarterCharacterScripts заменяет стандартную регенерацию Roblox
-- (1% ХП в секунду). Регенерацию считает сервер (CharacterService) по прокачанной характеристике «Регенерация».
return nil
"""


def main():
    for src, dst in COPIES.items():
        with open(os.path.join(REC, src), encoding="utf-8") as handle:
            text = handle.read().replace("\r\n", "\n")
        if src.endswith("Animator.luau") and "SlimeBounce" not in text:
            assert text.count(ANIM_OLD) == 1, "Animator anchor not found"
            text = text.replace(ANIM_OLD, ANIM_NEW)
        path = os.path.join(ROOT, dst)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print("imported", dst)
    path = os.path.join(ROOT, "src/character/Health.server.luau")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(HEALTH)
    print("wrote src/character/Health.server.luau")


if __name__ == "__main__":
    main()
