## PietInterpreter
Interpreter for the Piet language written in Perl<br>
V0.97a

### Disclaimer
Fractalwizz is not the author of any of the example programs.<br>
They are only provided to test the interpreter's functionality

### Module Dependencies
GD<br>
Data::Dumper<br>
Getopt::Std<br>
File::Basename

### Usage
perl piet.pl [options] inputImage<br>
  -d:         Debug Stats Output<br>
  -t:         Image Trace Output<br>
  -s [int]:   Trace Codel Size (default: 60)<br>
  -c [int]:   Image Input Codel Size (default: determined)<br>
  -p [int]:   Step Restraint (default: infinite)<br>
  -v [int]:   Invalid Color Handling (default: treat as white)<br>
              (1: terminate) (2: treat as black)<br>
  -r:         Piet-to-Perl Translation (BETA)<br>
  inputImage: path of image<br>
  
ie:<br>
perl piet.pl -d -r ./Examples/hi.png<br>
perl piet.pl -t -s 80 99bottles.png<br>
perl piet.pl -p 100 -v 2 incomp.gif

### Features
Piet Esoteric Programming Language<br>
Supports GIF and PNG files<br>
Supports conversion for images with slightly off colors (24-bit)<br>
New in 0.9: Input buffered for programs requiring longer inputs<br>
Debug output of Execution Statistics (cmd parameter)<br>
Image output of trace through program execution (cmd parameter)<br>
Define Trace Output Codel Size (cmd parameter)<br>
Define Codel Size of input image (cmd parameter)<br>
Step Restraint option (cmd parameter)<br>
Various Option Handling of Invalid Colors (cmd parameter)<br>
Corner determination optimization: Credit: Mark Majcher<br>
New in 0.97: Piet-to-Perl Translation (cmd parameter)(BETA)

### TODO

### License
MIT License<br>
(c) 2016 Fractalwizz<br>
http://github.com/fractalwizz/PietInterpreter