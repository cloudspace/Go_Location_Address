# Go Location Address
A Go Microservice to return the nearest address for latitude and longitude.

#### Usage
Input must have 2 arguments:

1.  Latitude
2.  Longitude

#### Example Input - Output
-
Input:
```
go run main.go 33.1056113 -86.8459558
```
Output (Success):
```
{"error":"","address":"514 Hidden Valley Dr"}
```
-
Output (Failure):
```
{
  "error":"<error message>",
  "state":""
}
```

#### How to build a linux binary from osx
Requirements:

1. Golang environment set up
2. Git
3. Boot2docker running

```
go get github.com/cloudspace/Go_Location_Address
cd <Go_Location_Address Directory>
docker run --rm -v $(pwd):/src centurylink/golang-builder

```

In order for the golang-builder to work, you need to have the github url on the top line of main.go. It should look like this:
```
package main // import "github.com/cloudspace/Go_Location_Address"
```

#### How to build a docker image
A docker image has to be built for each state. Follow the instructions here: [Generate Docker Images - Instructions](GenerateDockerImages/Instructions.md)
