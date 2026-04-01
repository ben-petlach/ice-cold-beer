// Fixed hole sequences for each level.
// LEVEL_HOLES[level][step] gives the hole index into HOLE_X / HOLE_Y.
// step 0 = first target (bottom-most, highest Y); step 9 = last (top-most, lowest Y).
// Each level has 10 holes spread across all vertical bands and left/centre/right.
//
// Horizontal zones (approximate game X):
//   Left   = X < 65
//   Centre = X 65-90
//   Right  = X > 90
//
// Level 0:  L:32,16,8,7  C:35,27,24  R:29,14,5
// Level 1:  L:26,20,11,0 C:36,10     R:31,28,18,6
// Level 2:  L:34,22,15   C:17,13,1   R:33,30,25,3
// Level 3:  L:32,21,12   C:35,27,9,4 R:29,19,3

localparam LEVEL_COUNT = 4;
localparam HOLES_PER_LEVEL = 10;

localparam logic [5:0] LEVEL_HOLES [0:3][0:9] = '{
    /* level 0 */ '{6'd35, 6'd32, 6'd29, 6'd27, 6'd24, 6'd16, 6'd14, 6'd8,  6'd7,  6'd5 },
    /* level 1 */ '{6'd31, 6'd36, 6'd28, 6'd26, 6'd20, 6'd18, 6'd11, 6'd10, 6'd6,  6'd0 },
    /* level 2 */ '{6'd33, 6'd30, 6'd34, 6'd22, 6'd25, 6'd17, 6'd15, 6'd13, 6'd1,  6'd3 },
    /* level 3 */ '{6'd35, 6'd32, 6'd29, 6'd27, 6'd21, 6'd19, 6'd12, 6'd9,  6'd4,  6'd3 }
};
