import math
from fxpmath import Fxp

N = 24
screenWidth_float = 320
screenHeight_float = 180

def generate_map():
    worldMap = []
    for i in range(N):
        worldMap.append([])
        for j in range(N):
            if ((i == 0) or (i == N-1) or (j == 0) or (j == N-1)):
                worldMap[i].append(1)
            else:
                worldMap[i].append(0)
        # print(worldMap[i])
    return worldMap

def sim_dda(hcount_ray, stepX, stepY, rayDirX, rayDirY, deltaDistX, deltaDistY, posX, posY, sideDistX, sideDistY): #posX, posY, mapX, mapY, planeX, planeY, deltaDistX, deltaDistY, sideDistX, sideDistY, stepX, stepY):
    worldMap = generate_map()
    mapX_float = math.floor(posX)
    mapY_float = math.floor(posY)

    mapX = Fxp(math.floor(posX), signed=True, n_word=16, n_frac=8, rounding='around')
    mapY = Fxp(math.floor(posY), signed=True, n_word=16, n_frac=8, rounding='around')

    curr_mapX = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
    curr_mapY = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
    curr_sideDistX = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
    curr_sideDistY = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')

    curr_mapX.set_val((mapX).get_val())
    curr_mapY.set_val((mapY).get_val())
    curr_sideDistX.set_val((sideDistX).get_val())
    curr_sideDistY.set_val((sideDistY).get_val())


    print(f"curr_mapx: {curr_mapX.astype(float)}")
    print(f"curr_mapy: {curr_mapY.astype(float)}")
    print(f"curr_sideDistX: {curr_sideDistX.astype(float)}")
    print(f"curr_sideDisty: {curr_sideDistY.astype(float)}")




    lineHeight_Q8_8 = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')

    perpWallDist = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')

    hit = 0
    side = -1 #no hit

    while hit == 0:
        # Jump to the next map square in the ray's path
        if (curr_sideDistX < curr_sideDistY):
            curr_sideDistX.set_val((curr_sideDistX + deltaDistX).get_val())
            curr_mapX.set_val((curr_mapX + stepX).get_val())
            side = 0
            print('x is less')
            print(f"curr_mapx: {curr_mapX.astype(float)}")
            print(f"curr_sideDistX: {curr_sideDistX.astype(float)}")
        else:
            curr_sideDistY.set_val((curr_sideDistY + deltaDistY).get_val())
            curr_mapY.set_val((curr_mapY + stepY).get_val())
            print('y is less')
            print(f"curr_mapy: {curr_mapX.astype(float)}")
            print(f"curr_sideDisty: {curr_sideDistX.astype(float)}")
            side = 1

        # Check if the ray has hit a wall
        # print(f"curr_mapy: {curr_mapX.astype(int)}")
        # print(f"curr_sideDisty: {curr_sideDistX.astype(int)}")
        print(worldMap[curr_mapY.astype(int)][curr_mapY.astype(int)])
        if worldMap[curr_mapY.astype(int)][curr_mapY.astype(int)] > 0:
            hit = 1

    if side == 0: # hits  X side
        perpWallDist.set_val((curr_sideDistX - deltaDistX).get_val())
    else: #hits Y side
        perpWallDist.set_val((curr_sideDistY - deltaDistY).get_val())
    
    if perpWallDist > 0: # calculating line height
        lineHeight_Q8_8.set_val((screenHeight_float/perpWallDist).get_val())
    else:
        lineHeight_Q8_8.set_val(320)  # Fallback for edge cases

    lineHeight = int(lineHeight_Q8_8.astype(int))

    print(hcount_ray, lineHeight, side)

    return hcount_ray, lineHeight, side

# parameters: N, screenWidth, screenHeight, pos, dir, plane, cameraX, deltadist, sidedist, stepX/Y
def sim_raycast():
    screenWidth = Fxp(screenWidth_float, signed=True, n_word=24, n_frac=12)

    posX_float = 22.5
    posY_float = 12.5
    dirX_float = -1
    dirY_float = 0
    planeX_float = 0
    planeY_float = .66
    

    posX = Fxp(posX_float, signed=True, n_word=16, n_frac=8, rounding='around')
    posY = Fxp(posY_float, signed=True, n_word=16, n_frac=8, rounding='around')
    dirX = Fxp(dirX_float, signed=True, n_word=16, n_frac=8, rounding='around')
    dirY = Fxp(dirY_float, signed=True, n_word=16, n_frac=8, rounding='around')
    planeX = Fxp(planeX_float, signed=True, n_word=16, n_frac=8, rounding='around')
    planeY = Fxp(planeY_float, signed=True, n_word=16, n_frac=8, rounding='around')

    #TEST 1 (from lodev website) (pos: 22, 12), (dir: -1, 0), (plane: 0, 0.66)

    # print(f"pos: {posX.bin(frac_dot=True), posY.bin(frac_dot=True)}", f"dir: {dirX.bin(frac_dot=True), dirY.bin(frac_dot=True)}", f"plane: {planeX.bin(frac_dot=True), planeY.bin(frac_dot=True)}")
    mapX_float = math.floor(posX_float)
    mapY_float = math.floor(posY_float)
    mapX = Fxp(math.floor(posX_float), signed=True, n_word=16, n_frac=8, rounding='around')
    mapY = Fxp(math.floor(posY_float), signed=True, n_word=16, n_frac=8, rounding='around')
    print(f"mapX,mapY: {mapX.bin(frac_dot=True), mapY.bin(frac_dot=True)}")
    for h_count_float in range(29,30):
        print(f"pos: {posX_float, posY_float}", f"dir: {dirX_float, dirY_float}", f"plane: {planeX_float, planeY_float}")
        print(f"(AS FLOATS) pos: {posX.astype(float), posY.astype(float)}", f"dir: {dirX.astype(float), dirY.astype(float)}", f"plane: {planeX.astype(float), planeY.astype(float)}")
        print(f"pos: {posX.bin(frac_dot=True), posY.bin(frac_dot=True)}", f"dir: {dirX.bin(frac_dot=True), dirY.bin(frac_dot=True)}", f"plane: {planeX.bin(frac_dot=True), planeY.bin(frac_dot=True)}")
        print(f"h_count: {h_count_float}")
#       localparam SCREEN_WIDTH = 320;
#       localparam SCREEN_WIDTH_RECIPRICAL = 24'b0000_0000_0000_0000_0000_1101;
        h_count_ray_Q12_12 = Fxp(h_count_float, signed=True, n_word=24, n_frac=12, rounding='around')
        cameraX_float = 2 * (h_count_float / screenWidth_float) - 1
        cameraX_Q12_12 = Fxp(None, signed=True, n_word=24, n_frac=12, rounding='around')
        cameraX_Q12_12.set_val((2 * (h_count_ray_Q12_12 / screenWidth) - 1).get_val())
        # cameraX_Q12_12= 2 * (h_count_ray_Q12_12 / screenWidth) - 1
        # cameraX = cameraX_Q12_12.resize(True, 16, 8)
        cameraX = Fxp(cameraX_Q12_12, True, 16, 8, rounding='around')
        # rayDirXMath = dirX + (planeX * cameraX)
        # rayDirYMath = dirY + (planeY * cameraX)

        rayDirX_float = dirX_float + (planeX_float * cameraX_float)
        rayDirY_float = dirY_float + (planeY_float * cameraX_float)

        rayDirX = Fxp(None, signed=True, n_word=16, n_frac=8)
        rayDirY = Fxp(None, signed=True, n_word=16, n_frac=8)

        rayDirX.set_val((dirX + (planeX * cameraX)).get_val())
        rayDirY.set_val((dirY + (planeY * cameraX)).get_val())

        deltaDistX_float = abs(1 / rayDirX_float) if (rayDirY_float != 0) else 0
        deltaDistY_float = abs(1 / rayDirY_float) if (rayDirY_float != 0) else 0

        deltaDistX = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
        deltaDistY = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')

        deltaDistX.set_val((abs(1 / rayDirX) if (rayDirX.astype(float) != 0) else 0).get_val())
        deltaDistY.set_val((abs(1 / rayDirY) if (rayDirY.astype(float) != 0) else 0).get_val())

        sideDistX = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
        sideDistY = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
        stepX = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')
        stepY = Fxp(None, signed=True, n_word=16, n_frac=8, rounding='around')

        if(rayDirX.astype(float) < 0):
            stepX_float = -1
            stepX.set_val(stepX_float)

            sideDistX_float = (posX_float - mapX_float) * deltaDistX_float
            sideDistX.set_val(((posX - mapX) * deltaDistX).get_val())
        else:
            stepX_float = 1
            stepX.set_val(stepX_float)
            sideDistX = (mapX + 1.0 - posX) * deltaDistX
            sideDistX_float = (mapX_float + 1.0 - posX_float) * deltaDistX_float
            sideDistX.set_val(((mapX + 1 - posX) * deltaDistX).get_val())
        if(rayDirY.astype(float) < 0):
            stepY_float = -1
            stepY.set_val(stepY_float)
            sideDistY_float = (mapY_float + 1.0 - posY_float) * deltaDistY_float
            sideDistY.set_val(((mapY + 1 - posY) * deltaDistY).get_val())
        else:
            stepY_float = 1
            stepY.set_val(stepY_float)
            sideDistY_float = (mapY_float + 1.0 - posY_float) * deltaDistY_float
            sideDistY.set_val(((mapY + 1 - posY) * deltaDistY).get_val())
        
        # print('###################################')
        # print(f"h count: {h_count_ray}")
        print(f"cameraX w/o fp math: {cameraX_float}")
        print(f"cameraX as float: {cameraX_Q12_12.astype(float)}")
        print(f"cameraX in hex: {cameraX_Q12_12.hex()}")
        print(f"cameraX in 8.8: {cameraX.astype(float)}")
        print(f"cameraX in 8.8: {cameraX.hex()}")
        print(f"rayDir w/o fp math: {rayDirX_float}, {rayDirY_float}, deltaDist w/o fp math: {deltaDistX_float}, {deltaDistY_float}, sideDist w/o fp math: {sideDistX_float}, {sideDistY_float}")
        print(f"rayDir: {rayDirX.astype(float)}, {rayDirY.astype(float)}, (HEX: {rayDirX.hex()}, {rayDirY.hex()}), (BIN: {rayDirX.bin(frac_dot=True)}, {rayDirY.bin(frac_dot=True)})")
        print(f"deltaDist: {deltaDistX.astype(float)}, {deltaDistY.astype(float)}, (HEX: {deltaDistX.hex()}, {deltaDistY.hex()}), (BIN: {deltaDistX.bin(frac_dot=True)}, {deltaDistY.bin(frac_dot=True)})")
        print(f"sideDist: {sideDistX.astype(float)}, {sideDistY.astype(float)}, (HEX: {sideDistX.hex()}, {sideDistY.hex()}), (BIN: {sideDistX.bin(frac_dot=True)}, {sideDistY.bin(frac_dot=True)})")
        print(f"step: {stepX}, {stepY}")
        # print(f"sideDist: {sideDistX}, {sideDistY}")
        # print('values here should be correctly adjusted when dda_data_ready_out')

        print(sim_dda(h_count_float, stepX, stepY, rayDirX, rayDirY, deltaDistX, deltaDistY, posX, posY, sideDistX, sideDistY))

print(sim_raycast())




        





