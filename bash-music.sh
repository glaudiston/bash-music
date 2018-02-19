#!/bin/bash
# bash-music.sh
#
# Funcions to generate pcm raw data:
# notes, chords, and songs using bash and gnu tools
#
# https://github.com/glaudiston/bash-music
#
# It's great to learn how sound works
#
# A long time ago, we here able to play pcm data 
# just writing to /dev/dsp, this time is over.
# now, with alsa or pulse, we need to use aplay
#
# You can do it just as:
# a=$(mknote 440)
# echo $a | aplay
#

# I do recommend a software like
# https://ccrma.stanford.edu/software/snd/index.html
# it is good to visualize and edit the resulting songs

# NEXT_NOTE_CONSTANT=1.059463094

channels=1
sample_rate=8000    # how many samples in 1 second ? 
bytes_per_sample=2; # here each byte has 16 bits per sample 
bit_depth=$(( 8 * bytes_per_sample )) 
duration=$(( sample_rate * 1/8 ))       # If 8000 bytes = 1 second, then 2000 = 1/4 second.

# bash is nota too slow, spawn subshell is slow,
# let's try avoid it
# create file descriptors to reuse bc process 
# instead of call bc every time
coproc BC { bc -l; }
function calculate()
{
	echo "$1" >&${BC[1]} &&
	read r<&${BC[0]} &&
	echo $r;
}

# let's try a way to avoid use a subshell 
# every time we need to run any code to set a var
# let's use a single subshell
coproc DD { cat; }

PI=3.141592654
#TAU=$( calculate "2 * $PI" )
calculate "2 * $PI" >&${DD[1]}
read TAU <&${DD[0]}


# mknote is a function that returns 
# pcm raw data in post script format
# arguments:
#  $1 - frequency
# 	frequency table:
# 	http://www.deimos.ca/notefreqs/
#  $2 - wave type:
#	sine - default
#	square
#	sawtooth
#	triangle - buggy
#	bessel - buggy
function mknote ()
{
	hexfmt="%0$(( 2 * bytes_per_sample ))x";
	note_hz=$1
	frequency=$note_hz
	note_bytes_per_second=$(( sample_rate / note_hz ))
	# lead type (sine,square,sawtooth)
	wave_type=${2}
	wave_type=${wave_type:=sine}
	amplitude=$(( 2 ** bit_depth / 2  ))  # 16bits signed
	if [ $wave_type == square ]; then
		square_on=0;
		for t in `seq 0 $duration`
		do
			sample_module=$(( t % note_bytes_per_second ))
			[[ $sample_module == 0 ]] && square_on=$(( (square_on+1 ) % 2 ))
			if (( square_on > 0 )); then
				si=$(( amplitude - 1 ))
			else
				si=$(( amplitude ))
			fi;
			printf $hexfmt $si
		done
	elif [ $wave_type == sawtooth ]; then
		#  sample = (amp * envelope * (phase - floor(phase));
		for t in `seq 0 $duration`
		do
			sample_module=$(( t % note_bytes_per_second ))
			i=$(( ( ( amplitude * 2 ) / note_bytes_per_second ) * sample_module ))
			si=$(( i - amplitude ))
			if (( si < 0 )); then
				si=$(( amplitude + i ))
			fi;
			printf $hexfmt $si
		done
	elif [ $wave_type == sine ]; then
		# uint8_t sample = (amp * envelope * sin(2 * M_PI * phase)) + 128;
		for sample_step in `seq 0 $duration`
		do
			frequency=$note_hz
			#theta=$( calculate "$frequency * $TAU / $sample_rate" )
			calculate "scale=8; s( $TAU * ( ( $sample_step / $sample_rate ) / ( 1 / ( $frequency ) ) ) ) * $amplitude" >&${DD[1]}
			read f <&${DD[0]}
			calculate "scale=0; $f/1" >&${DD[1]}
			read i <&${DD[0]}
			# convert to signed
			if (( i < 0 )); then
				si=$(( amplitude * 2 + i  ))
			else
				si=$i
			fi;
			printf $hexfmt $si;
		done
	elif [ $wave_type == triangle ]; then
		for t in `seq 0 $duration`
		do
			sample_module=$(( t % note_bytes_per_second ))
			#theta=$( calculate "$frequency * $TAU / $sample_rate" )
			calculate "scale=8; ( $TAU * $frequency * $t * $sample_rate) " >&${DD[1]}
			read theta <&${DD[0]}
			step=$t;
			#sinval=$( calculate "s( $theta * $step )" >&${BC[1]} );
			calculate "c( $theta * $step )" >&${DD[1]} 
			read sinval <&${DD[0]}
			#i=$( calculate "$amplitude * $sinval / 1 " )
			calculate "scale=0;$amplitude * $sinval / 1 " >&${DD[1]}
			
			read i <&${DD[0]}
			# convert to signed
			if (( i < 0 )); then
				si=$(( amplitude * 2 + i  ))
			else
				si=$i
			fi;
			printf $hexfmt $si;
		done
	elif [ $wave_type == bessel ]; then
		for t in `seq 0 $duration`
		do
			calculate "scale=8;j( 0, $t / ($sample_rate / $frequency) ) * $amplitude" >&${DD[1]} 
			read besselval <&${DD[0]}
			calculate "scale=0; $besselval / 1" >&${DD[1]} 
			read i <&${DD[0]}
			# convert to signed
			if (( i < 0 )); then
				si=$(( amplitude * 2 + i  ))
			else
				si=$i
			fi;
			printf $hexfmt $(( si ));
		done;
	fi;
}

function mkchord()
{
	notes=$#;
	chord="";
	for (( s=0; s<duration; s++ ));
	do
		for note in $@;
		do
			sample="${note:$(( s * bytes_per_sample )):bytes_per_sample}";
			chord="${chord}$sample";
		done;
	done;
	echo -n "$chord";
}


c1_hz=128
cs1_hz=136
d=144
ds=152
e=161

b=242
c_hz=256
cs_hz=271


a_hz=440
#
#e_hz=$(( a_hz * 3 / 2 ))
#mkchord $(mknote $(( sample_rate / 440 )) ) $(mknote $(( sample_rate / 330 )) ) | aplay -fS16_BE -r$sample_rate -c2
#
#a=`mknote $(( sample_rate / a_hz ))`
#b=`mknote $(( sample_rate / b_hz ))`
#c=`mknote 30`
#d=`mknote 27`
#d3=`mknote 2`
#e2=`mknote 24`
#e3=`mknote 4`
#f=`mknote 8`
#g=`mknote 41`
#cis=`mknote 29`
#n=`mknote 32767`
## European notation.


#echo -ne "$g$g$e2$d$c$d$c$a$g$n$g$e$n$g$e2$d$c$c$b$c$cis$n$cis$d \
#$n$g$e2$d$c$d$c$a$g$n$g$e$n$g$a$d$c$b$a$b$c" 
# dsp = Digital Signal Processor

echo "Plaing square waves..."

A=$(mknote 440 square)
Bb=$(mknote 466 square)
B=$(mknote 494 square)
C=$(mknote 523 square)
Db=$(mknote 554 square)
D=$(mknote 587 square )
Eb=$(mknote 622 square)
E=$(mknote 659 square )
F=$(mknote 698 square)
Gb=$(mknote 740 square )
G=$(mknote 784 square )
Ab=$(mknote 830 square)

#echo -ne "$A$Bb$B$C$Db$D$Eb$E$F$Gb$G$Ab" | xxd --ps -r | aplay -f S16_BE --channels=$channels --rate=$sample_rate

echo "Plaing sine waves..."
A=$(mknote 440)
Bb=$(mknote 466)
B=$(mknote 494)
C=$(mknote 523)
Db=$(mknote 554)
D=$(mknote 587)
Eb=$(mknote 622)
E=$(mknote 659 )
F=$(mknote 698)
Gb=$(mknote 740)
G=$(mknote 784)
Ab=$(mknote 830)

# echo -ne "$A$Bb$B$C$Db$D$Eb$E$F$Gb$G$Ab" | xxd --ps -r | aplay -f S16_BE --channels=$channels --rate=$sample_rate

# echo -ne "$a$D$E$A$F$D$E$C$D$F$C$E $F$D$E$F$E$A$C$E$F$E$D$F $E$F$E$D$A$F$E$D$C$E$D$E $F$D$E$F$E$C$D$E$D$F$E$A" | xxd --ps -r | aplay -f S16_BE --channels=$channels --rate=$sample_rate
