import sys
import numpy as np
from PIL import Image

filename = sys.argv[1]
pixelnum_w = int(sys.argv[2])
pixelnum_h = int(sys.argv[3])

assert pixelnum_w % 20 == 0, "width({}) is not evenly divisble by 20".format(pixelnum_w)
assert pixelnum_h % 20 == 0, "height({}) is not evenly divisble by 20".format(pixelnum_h)

binnum_w = int(pixelnum_w/20)
binnum_h = int(pixelnum_h/20)

with open(filename, 'r') as f:
	data = f.read()
	img_raw = np.array(data.split('\n')[:-1])

img_raw = np.where(img_raw == '0', 255, img_raw)
img_raw = np.where(img_raw == '1', 0, img_raw)
img_bin = np.reshape(img_raw, (-1, 18*18))


i = 1
j = 0
img_packed_row = [[] for _ in range(binnum_h)]
for _bin in img_bin:
	result = np.reshape(_bin, (-1, 18))
	if i == 1:
		img_packed_row[j] = result
	else:
		img_packed_row[j] = np.concatenate((img_packed_row[j], result), axis=1)
	
	if i == binnum_w:
		j += 1
		i = 1
	else:
		i += 1

img_final = img_packed_row[0]
for i in range(1, len(img_packed_row)):
        img_final = np.concatenate((img_final, img_packed_row[i]),axis=0)

img = Image.fromarray(img_final.astype(np.uint8))
# img.show()
img.save('test_edge.jpg')