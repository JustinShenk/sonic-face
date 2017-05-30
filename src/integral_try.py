## Lets try to get the integral of our data somehow

print('Integral functions imported')

## Takes an original image and calculates the integral image
## cumsum takes an array as input 
## this works on our vector array as expected (sums over the vectors)
def i_image (orig_image):
	iimage = orig_image.cumsum(1).cumsum(0)
	return iimage;

## to get the integral over a certain rectangle, input the topleft and bottomright coordinates
## depending on the location of the corner points, take the correct values from the integral image

def get_integral (integral_image, topleftx, toplefty, bottomrightx, bottomrighty):
	
	integral = 0
	integral += integral_image[bottomrightx,bottomrighty]
	
	if (topleftx - 1 >= 0) and (toplefty - 1 >=0):
		integral += integral_image[topleftx - 1, toplefty - 1]
	
	if (topleftx - 1 >= 0):
		integral -= integral_image[topleftx - 1, bottomrighty]
		
	if (toplefty - 1 >= 0):
		integral -= integral_image[bottomrightx, toplefty - 1]
		
	return integral