## PietInterpreter
Interpreter for the Piet language written in Perl<br>
V0.7

### Module Dependencies
GD<br>
Data::Dumper<br>
Getopt::Std

### Usage
perl piet.pl [options] inputImage<br>
  -d: Debug Stats Output<br>
  -t: Image Trace Output<br>
  inputImage: path of image<br>
  
ie:<br>
perl piet.pl -d ./Examples/hi.png

### Features
Piet Esoteric Programming Language<br>
Supports GIF and PNG files<br>
Supports conversion for images with slightly off colors (24-bit)<br>
Debug Statistics of execution to pietdebug.out (cmd parameter)<br>
Image output of trace through program execution (cmd parameter)

### TODO
Implement Trace functionality<br>
Optimizations to avoid unnecessary work (boundary/corners)<br>
Cmd parameter for defining codel size<br>
Cmd parameter for defining trace image size<br>
Formatting / Documentation<br>
More image formats (?)

### License
MIT License<br>
(c) 2016 Fractalwizz<br>
http://github.com/fractalwizz/PietInterpreter