Brian Coyner's Changes
======================
- Added support for multiple lines in an error message
- Added support for "parameterized" tests (i.e. execute same test method with different input data)
  - See http://briancoyner.github.com/blog/2011/09/12/ocunit-parameterized-test-case/
- Renamed variables to match the actual intended use (viz. test_case -> test_method_name)
- Added support to recursively create the output directory (mkdir_p)


Introduction
======================

OCUnit2JUnit is a script that converts output from OCUnit to the format used by JUnit. The main purpose is to be able to parse output from Objective-C (OCUnit) test cases on a Java-based build server, such as [Jenkins](http://jenkins-ci.org/).

Usage
======================

* Put the script somewhere where your build server can read it
* Use this shell command to build: 

	`xcodebuild -t <target> -sdk <sdk> -configuration <config> | /path/to/ocunit2junit.rb`

* The output is, by default, in the `test-reports` folder
* If your build fails, this script will pass the error code
* All output is also passed along, so you will still see everything in your build log


More information
======================

Can be found in [this blog post](http://blog.jayway.com/2010/01/31/continuos-integration-for-xcode-projects/).


Licence
======================

Free to use however you want.
