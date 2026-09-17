# -*- coding: utf-8 -*-
"""Generate the R Twitter bird printed on a low isometric box HVIF icon."""

import io
import os
import re
import xml.etree.ElementTree as ET


def coord(value):
    encoded = int(round(value)) + 32
    if not 0 <= encoded <= 127:
        raise ValueError("HVIF coordinate outside the one-byte range")
    return bytes([encoded])


def polygon(points):
    data = bytearray([0x0A, len(points)])
    for x, y in points:
        data += coord(x) + coord(y)
    return data


def twitter_logo(project):
    """Sample the Wikimedia path and project it onto the diamond box top."""
    path = os.path.join(project, "assets", "Logo_of_Twitter.svg")
    root = ET.parse(path).getroot()
    element = root.find("{http://www.w3.org/2000/svg}path")
    tokens = re.findall(r"[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?",
                        element.attrib["d"])
    index = 0
    command = None
    x = y = 0.0
    start = (0.0, 0.0)
    points = []

    def number():
        nonlocal index
        value = float(tokens[index])
        index += 1
        return value

    def cubic(x0, y0, x1, y1, x2, y2, x3, y3):
        for step in range(1, 5):
            t = step / 4.0
            u = 1.0 - t
            points.append((
                u ** 3 * x0 + 3 * u * u * t * x1
                + 3 * u * t * t * x2 + t ** 3 * x3,
                u ** 3 * y0 + 3 * u * u * t * y1
                + 3 * u * t * t * y2 + t ** 3 * y3))

    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
            if command in "Zz":
                points.append(start)
                continue

        if command == "M":
            x, y = number(), number()
            start = (x, y)
            points.append(start)
            command = "L"
        elif command == "m":
            x, y = x + number(), y + number()
            start = (x, y)
            points.append(start)
            command = "l"
        elif command == "L":
            x, y = number(), number()
            points.append((x, y))
        elif command == "l":
            x, y = x + number(), y + number()
            points.append((x, y))
        elif command == "H":
            x = number()
            points.append((x, y))
        elif command == "h":
            x += number()
            points.append((x, y))
        elif command == "V":
            y = number()
            points.append((x, y))
        elif command == "v":
            y += number()
            points.append((x, y))
        elif command in "Cc":
            relative = command == "c"
            x1, y1, x2, y2, x3, y3 = (number() for _ in range(6))
            if relative:
                x1, y1 = x + x1, y + y1
                x2, y2 = x + x2, y + y2
                x3, y3 = x + x3, y + y3
            cubic(x, y, x1, y1, x2, y2, x3, y3)
            x, y = x3, y3
        else:
            raise ValueError("unsupported SVG command: %s" % command)

    # Inset the logo on the top plane, then apply the same isometric projection
    # as the box. This makes it read as artwork printed on the lid.
    projected = []
    for px, py in points:
        u = 0.18 + (px / 248.0) * 0.64
        v = 0.18 + (py / 204.0) * 0.64
        projected.append((32.0 + 26.0 * u - 26.0 * v,
                          9.0 + 13.0 * u + 13.0 * v))
    return projected


def build_icon(project):
    styles = [
        (224, 235, 242, 255),  # bright top
        (112, 153, 181, 255),  # left side
        (62, 103, 132, 255),   # right side
        (29, 155, 240, 255),   # Twitter bird
        (38, 66, 84, 255),     # lower rim shadow
    ]
    shapes = []

    def add(style, points):
        shapes.append((style, points))

    far = (32, 9)
    right = (58, 22)
    near = (32, 35)
    left = (6, 22)
    # Keep the box visibly three-dimensional at 16 px while making it read as
    # a thin R Markdown-style slab instead of a tall badge.
    depth = 7

    # Shallow side faces first, followed by the lid and its printed logo.
    add(4, [(7, 24), (32, 37), (57, 24),
            (57, 31), (32, 44), (7, 31)])
    add(1, [left, near, (32, near[1] + depth),
            (left[0], left[1] + depth)])
    add(2, [right, near, (32, near[1] + depth),
            (right[0], right[1] + depth)])
    add(0, [far, right, near, left])

    # The exact 2012–2023 Twitter bird supplied by Wikimedia Commons.
    add(3, twitter_logo(project))

    output = bytearray(b"ncif")
    output.append(len(styles))
    for color in styles:
        output.append(1)
        output += bytes(color)
    output.append(len(shapes))
    for _, points in shapes:
        output += polygon(points)
    output.append(len(shapes))
    for index, (style, _) in enumerate(shapes):
        output += bytes([0x0A, style, 1, index, 0])
    return bytes(output)


def resource(data):
    value = "".join("%02X" % byte for byte in data)
    lines = ["resource vector_icon {"]
    lines += [
        '\t$"%s"' % value[index:index + 64]
        for index in range(0, len(value), 64)
    ]
    lines.append("};")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    project = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    path = os.path.join(project, "RTwitter.rdef")
    text = io.open(path, encoding="utf-8").read()
    block = re.compile(r"^resource vector_icon \{.*?^\};\n?", re.S | re.M)
    if len(block.findall(text)) != 1:
        raise SystemExit("RTwitter.rdef: expected one vector_icon resource")
    data = build_icon(project)
    io.open(path, "w", encoding="utf-8").write(
        block.sub(lambda _: resource(data), text, count=1))
    # The same bytes as a file, for the BEOS:ICON attribute the Makefile writes.
    with open(os.path.join(project, "assets", "RTwitter.hvif"), "wb") as f:
        f.write(data)
    print("RTwitter.rdef, assets/RTwitter.hvif: wrote %d-byte HVIF" % len(data))
