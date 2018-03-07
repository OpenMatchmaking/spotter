# spotter
Middleware for message queues-based microservices

This middleware layer is written for restricting an access to the certain message queues and doing pre-processing or validating data before passing it later to the next step. 

For example, it's very important for a cases when you should guaranteed that that data on each stage of pipeline will be correct and valid so that the last stage will send a response to the client as expected, instead of let it crash some stage without sending a detailed error.

# Features
- Restricting an access to the certain message queues (or resources) via checking permissions
- Pre-processing a input data before passing it for the processing further
