import sys
import math

def byte_to_233pixel(byte):
    val = ord(byte)  # Convert single-character str to int (0-255)
    R = (val >> 6) & 0b11
    G = (val >> 3) & 0b111
    B = val & 0b111

    return chr(R * 85) + chr(G * 36) + chr(B * 36)

def encode_file_to_ppm(input_filename, output_filename, width=256):
    f = open(input_filename, 'rb')
    data = f.read()
    f.close()

    length = len(data)
    height = int(math.ceil(float(length) / width))
    padded_length = width * height
    data += '\x00' * (padded_length - length)

    f = open(output_filename, 'wb')
    f.write("P6\n%d %d\n255\n" % (width, height))

    for i in range(padded_length):
        f.write(byte_to_233pixel(data[i]))

    f.close()
    print("Wrote %d bytes into %dx%d image: %s" % (length, width, height, output_filename))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python encode233.py inputfile output.ppm [width=256]")
        sys.exit(1)

    width = 256
    if len(sys.argv) > 3:
        width = int(sys.argv[3])

    encode_file_to_ppm(sys.argv[1], sys.argv[2], width)
