def BRANCH_ACTUAL = env.CHANGE_BRANCH ? env.CHANGE_BRANCH : env.BRANCH_NAME
pipeline {
    agent {
        node {
            label 'ec2-fleet'
            customWorkspace("/tmp/workspace/${env.BUILD_TAG}")
        }
    }

    options {
        timeout time: 1, unit: 'HOURS'
        timestamps()
        ansiColor 'xterm'
    }

    environment {
        GITHUB_TOKEN = credentials('github-api-token')
    }

    stages {
        stage('Setup') {
            steps {
                sh "git checkout ${BRANCH_ACTUAL}"
            }
        }

        stage('Build') {
            steps {
                sh 'make build'
                archiveArtifacts allowEmptyArchive: true, artifacts: 'release/*.yaml', caseSensitive: false, followSymlinks: false
            }
        }

        stage('Lint') {
            steps {
                sh 'make lint'
            }
        }

        stage('Test') {
            steps {
                sh 'make test'
            }
        }

        stage('Publish') {
            when {
                branch 'main'
            }

            steps {
                sh 'make publish'
            }
        }
    }
}
