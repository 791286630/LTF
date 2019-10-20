# Linux-Test-Framework

Linux automated testing framework
https://github.com/843723683/LTF
	
一. Running tests

1. To run these tests on your local machine :

./Run.sh -a

2. Run only performance tests (config/*.xml) :

./Run.sh -f benchmark.xml

3. Only perform the installation test. Only for performance testing. Avoid architecture, cpu and other abnormal interrupt tests

./Run.sh -f benchmark.xml -i

二. Writing tests

  Feel free to add the test modules you want to make. For example, the "Linux Command" test. You can create the "commands" folder in the testcases directory. And add the corresponding xml file in the config directory.
    
  There is an xml parsing script in the lib folder. Use "source xmlParse.sh" if necessary
