#!groovy
def downloaddir = '/var/tmp/nifidownload' //reuse download


pipeline {
    agent {
        label "java"
    }
    parameters {
        booleanParam(name: 'build_csd', defaultValue: true, description: 'Build the csd')
        booleanParam(name: 'build_parcel', defaultValue: false, description: 'Build the parcel')
    }

    options {
        disableConcurrentBuilds()  
        buildDiscarder(logRotator(numToKeepStr: '8',daysToKeepStr: '30'))
    }
    environment {
        TODO=''
    }
    triggers { cron("H H/4 * * *") }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
//                 sh "git tag puppet-v${revision} && git push --tags"
                dir('cm_ext') {
                    git branch: 'master', url: 'https://github.com/cloudera/cm_ext'
                    sh 'cd validator && mvn install'
                }
            }//steps
        }//end stage checkout

        stage('Check CSD') {
            steps {
                sh "java -jar cm_ext/validator/target/validator.jar -s csd-src/descriptor/service.sdl"
            }
        }//end stage check dirs

        stage('Build CSD') {
            steps {
                sh "mkdir -p build-csd"
                sh "cd csd-src && jar -cvf ../build-csd/NIFI-1.0.jar *"
            }
        }//end stage check dirs


        stage('archive CSD') {
            steps {
                archiveArtifacts artifacts: 'build-csd/*.jar', onlyIfSuccessful: true
            }
        }//end upload


    } // end stages

    post {
        failure {
            echo 'Build failed'
        }
        success {
            echo 'Build ok'
        }
    }

}
