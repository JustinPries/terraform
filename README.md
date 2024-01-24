This is a combination of playing around with Terraform and practicing IaC with resent AWS Certification. One night I created a Wordpress blog, then another day I created a static S3 website to host my resume. 
Kind of a mixture of the popular "CLOUD RESUME PROJECT", Udemy Courses and just messing around. Some of it is copy pasta, like the bash script I used to import my existing Route 53 zone into terraform.

However it's much more of a Frankenstein of gaggles of tutorials online, if nothing else I became a master of closing out google chrome tabs.

the HCL/Terraform stuff though is legitimately me just spending hours and hours banging my head and learning by doing.

I have no professional background as a software developer. I'm just a network engineer who has worn a lot of hats in IT and likes to tinker. I've worked in environments that had cloud, but I was never the cloud guy.


One thing I have loved about learning Terraform and AWS is the infinite amount of rabbit holes to go down. You start out thinking how do I host my resume on S3? Simple right?

Next thing I know it feels like I have a Myspace all of over again tinkering around with html and css. Then I'm figuring out how to make sure the html and css are on my bucket and playing nice.

Next thing I know I'm looking up how to create a cloud front distribution to point to that. Then I notice my resume has some typos and my cloudfront distribution has that cached.

Now I am learning how to invalidate a cloud front distribution from aws cli on the fly. Get that figure out?

Cool now my route 53 configuration isn't working. justinpriest.io is giving me error 403, but my cloud front link and s3 bucket link both pull up my resume

Now I'm learning I need a certificate on my cloud front distribution so I can point justinpriest.io to my cloudfront url to get people to my S3 bucket site.

and the biggest kicker is its easy enough to find quick tutorials for all this stuff online, but to do it all with terraform? Now I'm digging into the Terraform AWS Provider documentation 

reading countless medium blog post finding something promising then realizing what they did was deprecated so I need to adjust which is a whole new rabbit hole. A mixture of trial and error. Running terraform plan tracking down the line the error is on, reading more documentation getting it all FIGURED OUT running Terraform Apply and then boom another error that didn’t pop up when running terraform plan.

This basic repository probably contains a lot of elementary work to some veterans, but the process of learning all of this has been extremely fun, it’s like a never ending puzzle and brain just can’t stop until I fix it. I can only imagine how complex those puzzles grow in major enterprise cloud environments with huge production applications. Sounds challenging, but also sounds like a great way to learn.
