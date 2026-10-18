"""DESIGN.pen 에서 내보낸 아이콘 PDF 의 흰 바탕 사각형을 지운다.

Pencil 은 24×24 틀을 PDF 로 내보낼 때 페이지 전체를 흰색으로 칠한다(`0 0 24 24 re f`).
DSKit 아이콘은 템플릿 렌더링이라 이 사각형까지 색으로 칠해져 네모가 된다.
내용 스트림에서 그 사각형만 지우고 객체 오프셋(xref)을 다시 계산해 저장한다.

사용: python3 Tools/strip_pdf_bg.py <내보낸.pdf> <저장할.pdf>   — 지운 사각형 수를 출력한다(정상이면 1)
"""
import re, sys, zlib

BG = re.compile(rb"1 1 1 RG 1 1 1 rg\n(?:/G\d+ gs\n)?0 0 24 24 re\nf\n")

def rewrite(src, dst):
    data = open(src, "rb").read()
    header = data[: data.index(b"\n") + 1]
    objs = re.findall(rb"(\d+) 0 obj\s*(.*?)endobj", data, re.S)
    trailer = re.search(rb"trailer\s*(<<.*?>>)", data, re.S).group(1)
    removed = 0
    out = bytearray(header)
    offsets = {}
    for num, body in objs:
        m = re.search(rb"stream\r?\n", body)
        length = re.search(rb"/Length (\d+)", body[: m.start()]) if m else None
        if m and length and b"/FlateDecode" in body[: m.start()]:
            # 압축 데이터 끝에 줄바꿈 바이트가 올 수 있어 /Length 로 정확히 자른다.
            raw = zlib.decompress(body[m.end(): m.end() + int(length.group(1))])
            new, n = BG.subn(b"", raw)
            if n:
                removed += n
                comp = zlib.compress(new)
                dict_part = re.sub(rb"/Length \d+", b"/Length %d" % len(comp), body[: m.start()])
                body = dict_part + b"stream\n" + comp + b"\nendstream\n"
        offsets[int(num)] = len(out)
        out += num + b" 0 obj\n" + body.strip() + b"\nendobj\n"
    xref = len(out)
    size = max(offsets) + 1
    out += b"xref\n0 %d\n0000000000 65535 f \n" % size
    for i in range(1, size):
        out += (b"%010d 00000 n \n" % offsets[i]) if i in offsets else b"0000000000 65535 f \n"
    trailer = re.sub(rb"/Size \d+", b"/Size %d" % size, trailer)
    out += b"trailer\n" + trailer + b"\nstartxref\n%d\n%%%%EOF\n" % xref
    open(dst, "wb").write(out)
    return removed

if __name__ == "__main__":
    print(rewrite(sys.argv[1], sys.argv[2]))
