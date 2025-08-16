from PIL import Image
import sys
from math import floor, ceil

def closest(value, levels):
    return min(levels, key=lambda x: abs(x - value))

def pixel_to_byte_avg(r, g, b):
    R_levels = [0, 85, 170, 255]
    G_levels = [0, 36, 72, 108, 144, 180, 216, 252]
    B_levels = G_levels

    r = closest(r, R_levels)
    g = closest(g, G_levels)
    b = closest(b, B_levels)

    R = R_levels.index(r)
    G = G_levels.index(g)
    B = B_levels.index(b)

    return (R << 6) | (G << 3) | B

def byte_to_rgb(byte):
    R_levels = [0, 85, 170, 255]
    G_levels = [0, 36, 72, 108, 144, 180, 216, 252]
    B_levels = G_levels

    R = (byte >> 6) & 0b11
    G = (byte >> 3) & 0b111
    B = byte & 0b111

    return (R_levels[R], G_levels[G], B_levels[B])

def avg_block_fractional(pixels, y_start, y_end, x_start, x_end, img_w, img_h):
    x_min = max(0, floor(x_start))
    x_max = min(img_w - 1, ceil(x_end) - 1)
    y_min = max(0, floor(y_start))
    y_max = min(img_h - 1, ceil(y_end) - 1)

    # Compute mid positions inside the block (avoid edges)
    mid_x1 = x_min + (x_max - x_min) // 2
    mid_x2 = mid_x1 + 1 if mid_x1 + 1 <= x_max else mid_x1

    mid_y1 = y_min + (y_max - y_min) // 2
    mid_y2 = mid_y1 + 1 if mid_y1 + 1 <= y_max else mid_y1

    # Collect the middle 4 pixels
    sample_points = [
        (mid_x1, mid_y1),
        (mid_x1, mid_y2),
        (mid_x2, mid_y1),
        (mid_x2, mid_y2),
    ]

    r_sum = g_sum = b_sum = 0
    count = 0

    for (x, y) in sample_points:
        r, g, b = pixels[y * img_w + x]
        r_sum += r
        g_sum += g
        b_sum += b
        count += 1

    if count == 0:
        return (0, 0, 0)
    return (r_sum // count, g_sum // count, b_sum // count)


def decode_from_screenshot_fractional(image_path, output_path, orig_width, scale=16):
    img = Image.open(image_path).convert("RGB")
    img_w, img_h = img.size
    pixels = list(img.getdata())

    stride_x = img_w / orig_width
    stride_y = stride_x
    rows = round(img_h / stride_y)

    print(f"Image: {img_w}x{img_h}, fractional block size: {stride_x:.3f}px (w) x {stride_y:.3f}px (h)")
    print(f"Decoded image size: {orig_width}x{rows} bytes, total bytes: {orig_width * rows}")

    data = bytearray()
    recon_img = Image.new("RGB", (orig_width, rows))
    recon_pixels = recon_img.load()

        # ... your decoding loops ...

    for row in range(rows):
        y_start = row * stride_y
        y_end = y_start + stride_y
        for col in range(orig_width):
            x_start = col * stride_x
            x_end = x_start + stride_x

            avg_r, avg_g, avg_b = avg_block_fractional(pixels, y_start, y_end, x_start, x_end, img_w, img_h)
            byte = pixel_to_byte_avg(avg_r, avg_g, avg_b)
            data.append(byte)
            recon_pixels[col, row] = byte_to_rgb(byte)

    # Remove trailing null bytes (0x00) from data
    while data and data[-1] == 0:
        data.pop()

    with open(output_path, "wb") as f:
        f.write(data)

    recon_img = recon_img.resize((orig_width * scale, rows * scale), Image.NEAREST)
    recon_img.save("reconstructed.png")

    print(f"Decoded {len(data)} bytes to {output_path}")
    print(f"Reconstructed image saved as reconstructed.png (scaled {scale}x)")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: python {sys.argv[0]} screenshot.png output.bin original_width")
        sys.exit(1)

    image_path = sys.argv[1]
    output_path = sys.argv[2]
    orig_width = int(sys.argv[3])
    decode_from_screenshot_fractional(image_path, output_path, orig_width)
