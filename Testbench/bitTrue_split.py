import sys
import copy
import numpy as np
from PIL import Image

from scipy.ndimage.filters import convolve
from scipy.signal import medfilt2d

width = 200 #900
height = 200  #600

## output data
pixel_in = [[] for i in range(5)]
pixel_out = []

## Utility funciton
def grayscale(rgb):
    return (np.dot(rgb[..., :3], [0.299, 0.587, 0.114])/16).astype(int)

def SerialIn(img, kernal_size=3):
    H, W = img.shape

    # to serial input
    resulting_img = []
    D = range(16)
    for i in range(H-kernal_size+1):
        row = []
        for j in range(W):
            pack = []
            for k in range(kernal_size):
                temp = img[i+k][j]
                if(temp not in D):
                    print(temp)
                assert(temp in D)
                pack.append(temp)
            row.append(pack)
        resulting_img.append(row)
    return resulting_img

def Padding(orig_img, padnum=1, printPad=False, noPad=False, file=False):
    # When doing Median and Sobel, padnum = 1; when doing Gaussian, padnum = 2

    # padding
    if not noPad:
        img = np.pad(orig_img, padnum, mode='edge')
    else:
        img = orig_img

    if printPad:
        print(img)

    if file:
        assert(img.shape == (20, 20))
        global pixel_in

        for row in img:
            for i in range(4):
                pixel_in[0].append("{0:04b}".format(row[5*i]))
                pixel_in[1].append("{0:04b}".format(row[5*i+1]))
                pixel_in[2].append("{0:04b}".format(row[5*i+2]))
                pixel_in[3].append("{0:04b}".format(row[5*i+3]))
                pixel_in[4].append("{0:04b}".format(row[5*i+4]))

        # for i in range(5):
        #     with open("pattern/input_pixel/pixel_in" + str(i) + ".dat", 'w') as f:
        #         f.write('\n'.join(pixel_in[i]))

    return img

def show_edge(img):
    img = np.where(img==False, 255, img)
    img = np.where(img==True, 0, img)
    img_final = Image.fromarray(img.astype(np.int32))
    img_final.show()

def split_img(img, split_size):
    h, w = img.shape
    assert h % split_size == 0, "{} rows is not evenly divisble by {}".format(h, split_size)
    assert w % split_size == 0, "{} cols is not evenly divisble by {}".format(w, split_size)
    return (img.reshape(h//split_size, split_size, -1, split_size)
               .swapaxes(1,2)
               .reshape(-1, split_size, split_size))

# ================== Median Filter ================== #

def comparator(a, b):
    if a > b: return a, b
    else: return b, a

def Median(img, debug=False, file=False):
    H, W = img.shape
    Padding(img,file=True, noPad=True)
    serial = SerialIn(img, kernal_size=3)

    img_med = []


    if file:
        golden = []

    for i in range(H-2):
        A = serial[i][0:2]

        med_row = []

        for j in range(W-2):
            A.append(serial[i][j+2])
            # TODO
            # print(A)

            x0, x1, x2 = A[0][0], A[0][1], A[0][2]
            x3, x4, x5 = A[1][0], A[1][1], A[1][2]
            x6, x7, x8 = A[2][0], A[2][1], A[2][2]

            x0, x1 = comparator(x0, x1) # 1
            x3, x4 = comparator(x3, x4) # 2
            x6, x7 = comparator(x6, x7) # 3

            x1, x2 = comparator(x1, x2) # 4
            x4, x5 = comparator(x4, x5) # 5
            x7, x8 = comparator(x7, x8) # 6

            x0, x1 = comparator(x0, x1) # 7
            x3, x4 = comparator(x3, x4) # 8
            x6, x7 = comparator(x6, x7) # 9

            _, wire1 = comparator(x0, x3) # 10
            wire2, wire3 = comparator(x1, x4) # 11
            wire4, _ = comparator(x5, x8) # 12

            _, wire5 = comparator(wire1, x6) # 13
            wire6, _ = comparator(wire3, x7) # 14
            wire7, _ = comparator(x2, wire4) # 15

            _, wire8 = comparator(wire2, wire6) # 16

            wire9, wire10 = comparator(wire5, wire8) # 17

            wire11, _ = comparator(wire10, wire7) # 18

            _, median = comparator(wire9, wire11) # 19

            med_row.append(median)

            if file:
                golden.append(median)

            # End TODO
            del A[0]

        img_med.append(med_row)

    if file:
        with open("pattern/Median/out_golden.dat", 'w') as f:
            f.write('\n'.join(map("{0:04b}".format, golden)))
        with open("pattern/Median/out_square", 'w') as f:
            square = []
            for i in range(18):
                square.append(' '.join(map(str, golden[18*i:18*(i+1)])))
            f.write('\n'.join(square))

    # return type should be a 2-dimensional numpy array representing the grayscale of the image.
    # Elements in the numpy array should be integer type within 0~31.
    img_pad = Padding(np.array(img_med), padnum=1)
    return img_pad

# ================== Gaussian Filter ================== #

def filter_col_0(img_col):
    sum0 = img_col[0] << 1
    sum1 = img_col[1] << 2
    sum2 = (img_col[2] << 2) + img_col[2]
    sum3 = img_col[3] << 2
    sum4 = img_col[4] << 1
    # print(img_col)
    # print(sum0, sum1, sum2, sum3, sum4)
    return sum0 + sum1 + sum2 + sum3 + sum4

def filter_col_1(img_col):
    sum0 = img_col[0] << 2
    sum1 = (img_col[1] << 3) + img_col[1]
    sum2 = (img_col[2] << 2) + (img_col[2] << 3)
    sum3 = (img_col[3] << 3) + img_col[3]
    sum4 = img_col[4] << 2
    # print(img_col)
    # print(sum0, sum1, sum2, sum3, sum4)
    return sum0 + sum1 + sum2 + sum3 + sum4

def filter_col_2(img_col):
    sum0 = (img_col[0] << 2) + img_col[0]
    sum1 = (img_col[1] << 2) + (img_col[1] << 3)
    sum2 = (img_col[2] << 4) - img_col[2]
    sum3 = (img_col[3] << 2) + (img_col[3] << 3)
    sum4 = (img_col[4] << 2) + img_col[4]
    # print(img_col)
    # print(sum0, sum1, sum2, sum3, sum4)
    return sum0 + sum1 + sum2 + sum3 + sum4

def sum_n_divide(sum0, sum1, sum2, sum3, sum4):
    sum = sum0 + sum1 + sum2 + sum3 + sum4

    gau = ((sum >> 7) - (sum >> 9)) + ((sum >> 11) - (sum >> 14))
    
    return gau

def Gaussian(img, debug=False, file=False):
    H, W = img.shape
    serial = SerialIn(img, kernal_size=5)

    img_gau = []

    if file:
        golden = []

    for i in range(H-4):
        A = serial[i][0:4]

        gau_row = []

        for j in range(W-4):
            A.append(serial[i][j+4])
            # TODO
            # print(A)

            sum0 = filter_col_0(A[0])
            sum1 = filter_col_1(A[1])
            sum2 = filter_col_2(A[2])
            sum3 = filter_col_1(A[3])
            sum4 = filter_col_0(A[4])

            gau = sum_n_divide(sum0, sum1, sum2, sum3, sum4)
            
            gau_row.append(gau)

            if file:
                golden.append(gau)
            # End TODO
            del A[0]

        img_gau.append(gau_row)


    if file:
        with open("pattern/Gaussian/out_golden.dat", 'w') as f:
            f.write('\n'.join(map("{0:04b}".format, golden)))
        with open("pattern/Gaussian/out_square", 'w') as f:
            square = []
            for i in range(16):
                square.append(' '.join(map(str, golden[16*i:16*(i+1)])))
            f.write('\n'.join(square))

    # return type should be a 2-dimensional numpy array representing the grayscale of the image.
    # Elements in the numpy array should be integer type within 0~31.
    img_pad = Padding(np.array(img_gau), padnum=2)
    return img_pad   
# ================== Sobel Convolution================== #
def sign(number): # extend number to 8 bits  
    if number >= 0: return 0
    else: return 1
def sobel_col0(img_col):
    sum0=(img_col[0]*-1)
    sum1=(img_col[1]*-2)
    sum2=(img_col[2]*-1)
    return sum0+sum1+sum2
#def sobel_col1(img_col):
#   return 0
def sobel_col2(img_col):
    sum0=(img_col[0])
    sum1=(img_col[1])<<1
    sum2=(img_col[2])
    return sum0+sum1+sum2
def sobel_col3(img_col):
    sum0=(img_col[0])
    sum2=(img_col[2]*-1)
    return sum0+sum2
def sobel_col4(img_col):
    sum0=(img_col[0])<<1
    sum2=(img_col[2])*-2
    return sum0+sum2
def sobel_col5(img_col):
    sum0=(img_col[0])
    sum2=(img_col[2])*-1
    return sum0+sum2
def sign_XOR(Gx_MSB,Gy_MSB):
    return Gx_MSB ^ Gy_MSB
def tangent_22_5(G):
    return (G>>2) + (G>>3) + (G>>5) + (G>>7)
def angle_judge(sign,Gxt,Gyt):
    if ((not Gxt) and (not Gyt)): 
        if(sign): return 3#01 45
        else : return 1#11 135
    else :
        if(Gxt): return 0 #  0
        else : return 2 #10 90
def compare_bool(n1,n2):
    if n1>n2 : return True
    else : return False

def Sobel(img, debug=False, file=False):
    H, W = img.shape
    serial = SerialIn(img, kernal_size=3)
    count = 0

    if file:
        golden_ang = []
        golden_grad = []

    img_angle=[]
    img_gradient=[]
    for i in range(H-2):
        A = serial[i][0:2]

        angle_row=[]
        gradient_row=[]
        for j in range(W-2):
            A.append(serial[i][j+2])

            # TODO
            # print(A)
            sum0=sobel_col0(A[0])
            #sum1=sobel_col1(A[1])#=0
            sum2=sobel_col2(A[2])
            sum3=sobel_col3(A[0])
            sum4=sobel_col4(A[1])
            sum5=sobel_col5(A[2])

            
            # if count == 25:
            #     print(A)
            #     print(sum0)
            #     print(0)
            #     print(sum2)
            #     print(sum3)
            #     print(sum4)
            #     print(sum5)
            #     print()
            count += 1

            Gx=sum0+sum2# 8 bits
            Gy=sum3+sum4+sum5# 8 bits
            Gx_val=abs(Gx)
            Gy_val=abs(Gy)
            Gradient=((Gx_val+Gy_val)>>2)
            Gx_tan=tangent_22_5(Gx_val)
            Gy_tan=tangent_22_5(Gy_val)
            Gxt=compare_bool(Gx_tan,Gy_val)
            Gyt=compare_bool(Gy_tan,Gx_val)
            co_sign=sign_XOR(sign(Gx),sign(Gy))
            angle=angle_judge(co_sign,Gxt,Gyt)
            angle_row.append(angle)
            gradient_row.append(Gradient)

            if file:
                golden_grad.append(Gradient)
                golden_ang.append(angle)

            # End TODO
            del A[0]
        img_angle.append(angle_row)
        img_gradient.append(gradient_row)

    if file:
        with open("pattern/Sobel/golden_grad.dat", 'w') as f:
            f.write('\n'.join(map("{0:04b}".format, golden_grad)))
        with open("pattern/Sobel/golden_ang.dat", 'w') as f:
            f.write('\n'.join(map("{0:02b}".format, golden_ang)))
        with open("pattern/Sobel/out_square_grad", 'w') as f:
            square = []
            for i in range(18):
                square.append(' '.join(map(str, golden_grad[18*i:18*(i+1)])))
            f.write('\n'.join(square))
        with open("pattern/Sobel/out_square_ang", 'w') as f:
            square = []
            for i in range(18):
                square.append(' '.join(map(str, golden_ang[18*i:18*(i+1)])))
            f.write('\n'.join(square))

    # First return:     return type should be a 2-dimensional numpy array representing the gradient of the image.
    #                   Elements in the numpy array should be integer type within 0~31.
    # Second return:    return type should be a 2-dimensional numpy array representing the edge angle of the image.
    #                   Elements in the numpy array should be 2-bit binary strings, ex: "01".
    img_grad_pad = Padding(np.array(img_gradient), padnum=1)
    return img_grad_pad, np.array(img_angle)
# ================== Sobel Convolution================== #

def nonMax(gradient, angle, debug=False, file=False):
    H, W = angle.shape
    serial = SerialIn(gradient, kernal_size=3)

    if file:
        golden = []

    img_med = []
    for i in range(H):
        A = serial[i][0:2]

        med_row = []
        for j in range(W):
            A.append(serial[i][j+2])
            ang = angle[i][j]

            # TODO
            # print(A)
            # print(ang)

            # MUX
            if ang  == 0:
                pix1 = A[0][1]
                pix2 = A[2][1]
            elif ang == 1:
                pix1 = A[0][2]
                pix2 = A[2][0]
            elif ang == 2:
                pix1 = A[1][0]
                pix2 = A[1][2]
            elif ang == 3:
                pix1 = A[0][0]
                pix2 = A[2][2]
            else:
                print("Error: \"ang\" value error!!")


            if A[1][1] >= pix1 and A[1][1] >= pix2:
                result = A[1][1]
            else:
                result = 0

            med_row.append(result)

            if file:
                golden.append(result)
            # End TODO
            del A[0]

        img_med.append(med_row)

    if file:
        with open("pattern/nonMax/out_golden.dat", 'w') as f:
            f.write('\n'.join(map("{0:04b}".format, golden)))
        with open("pattern/nonMax/out_square", 'w') as f:
            square = []
            for i in range(18):
                square.append(' '.join(map(str, golden[18*i:18*(i+1)])))
            f.write('\n'.join(square))

    # return type should be a 2-dimensional numpy array representing the modified gradient of the image.
    # Elements in the numpy array should be integer type within 0~31.
    img_pad = Padding(np.array(img_med), padnum=1)
    return img_pad

def Hysteresis(img, debug=False, file=False):
    H, W = img.shape
    serial = SerialIn(img, kernal_size=3)

    weak = 0
    strong = 2

    global pixel_out
    if file:
        golden = []

    img_med = []
    for i in range(H-2):
        A = serial[i][0:2]

        med_row = []
        for j in range(W-2):
            A.append(serial[i][j+2])

            # TODO
            # print(A)
            result = None
            if A[1][1] <= weak:
                result = False
            elif A[1][1] >= strong:
                result = True
            else:
                for p in range(3):
                    for q in range(3):
                        if result == True:
                            pass
                        else:
                            if A[p][q] >= strong:
                                result = True
                            else:
                                result = False


            med_row.append(result)
            pixel_out.append(result)

            if file:
                golden.append(result)
            # End TODO
            del A[0]

        img_med.append(med_row)

    if file:
        with open("pattern/Hysteresis/out_golden.dat", 'w') as f:
            f.write('\n'.join(map("{0:01b}".format, golden)))
        with open("pattern/Hysteresis/out_square", 'w') as f:
            square = []
            for i in range(18):
                square.append(' '.join(map(lambda x: str(int(x)), golden[18*i:18*(i+1)])))
            f.write('\n'.join(square))
    # return type should be a 2-dimensional numpy array representing the modified gradient of the image.
    # Elements in the numpy array should be ???(True or False?).
    return np.array(img_med)

## === COPY ===
def sobel_filters(img):
    Kx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], np.float32)
    Ky = np.array([[1, 2, 1], [0, 0, 0], [-1, -2, -1]], np.float32)

    Ix = convolve(img, Kx)
    Iy = convolve(img, Ky)

    #G = np.hypot(Ix, Iy).astype(np.int32)
    G = (np.abs(Ix) + np.abs(Iy)) >> 3
    theta = np.arctan2(Iy, Ix)

    return (G, theta)

def gaussian_kernel(size, sigma=1):
        size = int(size) // 2
        x, y = np.mgrid[-size:size+1, -size:size+1]
        normal = 1 / (2.0 * np.pi * sigma**2)
        g =  np.exp(-((x**2 + y**2) / (2.0*sigma**2))) * normal
        return g

## === End COPY ===

def main():
    save = False
    split_size = 20
    global height, width, pixel_in, pixel_out

    orig_img = Image.open(sys.argv[1])
    orig_img = orig_img.resize((width, height), Image.ANTIALIAS)
    orig_img = grayscale(np.asarray(orig_img))
    Image.fromarray((orig_img*8).astype(np.uint8)).show()
    if save:
        Image.fromarray((orig_img*8).astype(np.uint8)).save("output/init.jpg")

    img_list = split_img(orig_img, split_size)
    bin_h = int(width/split_size)
    bin_v = int(height/split_size)
    image_result = [[] for _ in range(bin_v)]

    height = split_size - 2
    width = split_size - 2

    for i, img in enumerate(img_list):
        print("===== bin{} =====".format(i))
        #print("=== Median ===")
        img_med = Median(img)
        # img_med = img
        if save:
            Image.fromarray((img_med*8).astype(np.uint8)).save("output/med.jpg")

        #print("=== Gaussian ===")
        img_gau = Gaussian(img_med)
        # img_gau = img_med
        if save:
            Image.fromarray((img_gau*8).astype(np.uint8)).save("output/gau.jpg")

        #print("=== Sobel ===")
        img_grad, img_angle = Sobel(img_gau)
        if save:
            Image.fromarray((img_grad*16).astype(np.uint8)).save("output/grad.jpg")
            Image.fromarray((img_angle*64).astype(np.uint8)).save("output/angle.jpg")

        #print("=== nonMax ===")
        img_sup = nonMax(img_grad, img_angle)
        if save:
            Image.fromarray((img_sup*16).astype(np.uint8)).save("output/sup.jpg")

        #print("=== Hysteresis ===")
        img_final = Hysteresis(img_sup)
        if save:
            Image.fromarray((img_final*255).astype(np.uint8)).save("output/final.jpg")

        if i%bin_h == 0:
            image_result[int(i/bin_h)] = img_final
        else:
            image_result[int(i/bin_h)] = np.concatenate((image_result[int(i/bin_h)], img_final),axis = 1)

    image_final = image_result[0]
    for i in range(1, len(image_result)):
        image_final = np.concatenate((image_final, image_result[i]),axis = 0)

    show_edge(image_final)

    for i in range(5):
        with open("pattern/input_pixel/pixel_in" + str(i) + ".dat", 'w') as f:
            f.write('\n'.join(pixel_in[i]))

    with open("pattern/out_golden.dat", 'w') as f:
            f.write('\n'.join(map("{0:01b}".format, pixel_out)))



def test():
    img = np.arange(16).reshape((4,4))
    print(type(split_img(img, 2)))

if __name__ == '__main__':
    main()
    #test()
