# PietInterpreter
Interpreter for the Piet language written in Perl
V0.7

# Module Dependencies
GD:
Data::Dumper
Getopt::Std

# Usage
perl piet.pl [options] inputImage
  -d: Debug Stats Output
  -t: Image Trace Output
  inputImage: path of image
  
ie:
perl piet.pl -d ./Examples/hi.png
	

# Features
Piet Esoteric Programming Language
Supports GIF and PNG files
Supports conversion for images with slightly off colors (24-bit)
Debug Statistics of execution to pietdebug.out (cmd parameter)
Image output of trace through program execution (cmd parameter)

# TODO
Implement Trace functionality
Optimizations to avoid unnecessary work (boundary/corners)
Cmd parameter for defining codel size
Cmd parameter for defining trace image size
Formatting / Documentation
More image formats (?)

# License
MIT License
(c) 2016 Fractalwizz
http://github.com/fractalwizz/PietInterpreter