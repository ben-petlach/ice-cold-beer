// hole_positions.vh
// Top-left corners of all holes in 160x120 game-pixel space.
// Each hole is 8x8 with 3 corner pixels cut from each corner.
// Collision window: ball center within [HOLE_X+2, HOLE_X+5] x [HOLE_Y+2, HOLE_Y+5]

localparam HOLE_COUNT = 37;

localparam logic [6:0] HOLE_X [0:36] = '{
    52, 65, 73, 102, 83,   //  0- 4
    94, 105, 55, 43, 70,   //  5- 9
    82, 61, 48, 80, 109,   // 10-14
    40, 54, 69, 91, 104,   // 15-19
    43, 40, 49, 66, 86,    // 20-24
   106, 54, 79, 95, 106,   // 25-29
   111, 102, 42, 54, 62,   // 30-34
    72, 79                 // 35-36
};

localparam logic [6:0] HOLE_Y [0:36] = '{
     7, 13,  7,  4,  6,   //  0- 4
    16, 18, 20, 21, 24,   //  5- 9
    21, 29, 32, 35, 32,   // 10-14
    40, 41, 44, 42, 47,   // 15-19
    51, 65, 61, 62, 52,   // 20-24
    59, 72, 70, 74, 83,   // 25-29
    92, 103, 87, 96, 85,  // 30-34
    93, 87                // 35-36
};
