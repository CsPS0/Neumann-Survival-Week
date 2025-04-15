import time
import sys

# List of ASCII frames
frames = [
    r"""
  O 
 /H\  
/ H \ 
 / \ 
/   \
    """,
    r"""
  O 
 /H\  
/ H \ 
 / \ 
/   \
    """,
    r"""
  O 
 /H/  
 \H\      
 | \ 
‾  / 
    """,
    r"""
  O   
  /     
  \     
  |  
 ‾|   
    """,
    r"""
  O    
  /     
  \     
  |\
 ‾|‾   
    """,
    r"""
  O 
 /H|  
 \H\  
 | \ 
/  / 
    """,
]

def play_animation(frames, delay=0.05):
    # Pre-calculate number of lines per frame
    frame_height = max(frame.count('\n') for frame in frames)

    while True:
        for frame in frames:
            print(frame, end="")
            time.sleep(delay)
            # Move cursor up by number of lines in the frame
            sys.stdout.write(f"\033[{frame_height}A")
            sys.stdout.flush()

if __name__ == "__main__":
    play_animation(frames)
