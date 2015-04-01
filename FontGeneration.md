## Export BDF fonts to C array for dotmatrix displays ##

In the repository is included a (scratch) script to exports BDF fonts to C array: [bdf2c.pl](http://code.google.com/p/dotmatrix-editor/source/browse/bdf2c.pl).

This script, derived from Markus Kuhn's ucs2any.pl, read ASCII printable (0x20 - 0x7f) characters from BDF files and generate a C array. This array is for **vertical scanline** (eg. HT1632C) dotmatrix displays.

Usage:
```
perl bdf2c.pl 7x14B.bdf
```

Example of resulting array:
```
// -Misc-Fixed-Bold-R-Normal--14-130-75-75-C-70-ISO10646-1
uint16_t PROGMEM font_7x14b[95][7] = {
{0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000}, //
{0x0000,0x0000,0x0fec,0x0fec,0x0000,0x0000,0x0000}, // !
...
{0x0e00,0x1800,0x0c00,0x0c00,0x0600,0x1c00,0x0000}, // ~
};
```

## Usefull links ##
  * [Glyph Bitmap Distribution Format](http://en.wikipedia.org/wiki/Glyph_Bitmap_Distribution_Format)
  * [Adobe Glyph Bitmap Distribution Format (BDF) Specification, version 2.2](http://partners.adobe.com/public/developer/en/font/5005.BDF_Spec.pdf)
  * [Fixed (typeface)](http://en.wikipedia.org/wiki/Fixed_%28typeface%29)
  * [Unicode fonts and tools for X11](http://www.cl.cam.ac.uk/~mgk25/ucs-fonts.html)