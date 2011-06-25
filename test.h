#include <stdint.h>

#define hello bowwow

// comment

/* comment */

/* comment
1
2
3

*/

unsigned char PROGMEM myfont[2][5] = {
  {0, 0, 0, 0, 0},
  {0b01111110,
   0b10010000,
    0b10010000,
     0b10010000,
  0b01111110}, /* A */
}


uint8_t PROGMEM myfont2[2][5] = {
  {0, 0, 0, 0, 0}, // trolololo
  {0b01111110,
   0b10010000,
    0b10010001,
     0b10010000,
      0b01111110}, // A
};

uint16_t PROGMEM pacman[1][14] = {
{ 0x03E0,    // ____XXXXX_____
  0x0FF8,    // __XXXXXXXXX___
  0x1FFC,    // _XXXXXXXXXXX__
  0x1FFC,    // _XXXXXXXXXXX__
  0x07FE,    // ___XXXXXXXXXX_
  0x01FE,    // _____XXXXXXXX_
  0x007E,    // _______XXXXXX_
  0x007E,    // _______XXXXXX_
  0x01FE,    // _____XXXXXXXX_
  0x07FE,    // ___XXXXXXXXXX_
  0x1FFC,    // _XXXXXXXXXXX__
  0x1FFC,    // _XXXXXXXXXXX__
  0x0FF8,    // __XXXXXXXXX___
  0x03E0,    // ____XXXXX_____
  },
}


uint16_t PROGMEM my7font[2][7] = {
{0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, }, //
{0x0000, 0x0000, 0x0000, 0x0fec, 0x0000, 0x0000, 0x0000, }, // !
}
