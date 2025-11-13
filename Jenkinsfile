pipeline {
    agent any
    
    environment {
        // Docker Hub credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'marvelhelmy' // CHANGE THIS to your Docker Hub username
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Frontend environment variables
        VITE_BACKEND_URL = 'http://localhost:3000'
        VITE_CURRENCY = '$'
        // Store credentials in separate variables
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Verify Structure') {
            steps {
                echo '📂 Checking repository structure...'
                bat 'dir'
                bat 'if exist client (echo Client folder found) else (echo ERROR: Client folder NOT found)'
                bat 'if exist server (echo Server folder found) else (echo ERROR: Server folder NOT found)'
            }
        }
        
        stage('Build Client Image') {
            steps {
                echo '🔨 Building Frontend Docker Image...'
                script {
                    dir('client') {
                        // Use bat instead of sh for Windows
                        bat """
                            docker build ^
                            --build-arg VITE_BACKEND_URL=%VITE_BACKEND_URL% ^
                            --build-arg VITE_CURRENCY=%VITE_CURRENCY% ^
                            --build-arg VITE_CLERK_PUBLISHABLE_KEY=%CLERK_KEY% ^
                            --build-arg VITE_STRIPE_PUBLISHABLE_KEY=%STRIPE_KEY% ^
                            -t %CLIENT_IMAGE%:%IMAGE_TAG% ^
                            -t %CLIENT_IMAGE%:latest ^
                            .
                        """
                    }
                }
            }
        }
        
        stage('Build Server Image') {
            steps {
                echo '🔨 Building Backend Docker Image...'
                script {
                    dir('server') {
                        bat """
                            docker build ^
                            -t %SERVER_IMAGE%:%IMAGE_TAG% ^
                            -t %SERVER_IMAGE%:latest ^
                            .
                        """
                    }
                }
            }
        }
        
        stage('Login to Docker Hub') {
            steps {
                echo '🔐 Logging into Docker Hub...'
                bat "echo %DOCKERHUB_CREDENTIALS_PSW% | docker login -u %DOCKERHUB_CREDENTIALS_USR% --password-stdin"
            }
        }
        
        stage('Push Images to Docker Hub') {
            steps {
                echo '📤 Pushing images to Docker Hub...'
                bat """
                    docker push %CLIENT_IMAGE%:%IMAGE_TAG%
                    docker push %CLIENT_IMAGE%:latest
                    docker push %SERVER_IMAGE%:%IMAGE_TAG%
                    docker push %SERVER_IMAGE%:latest
                """
            }
        }
        
        stage('Cleanup') {
            steps {
                echo '🧹 Cleaning up local images...'
                bat """
                    docker rmi %CLIENT_IMAGE%:%IMAGE_TAG% 2>nul || echo Image already removed
                    docker rmi %CLIENT_IMAGE%:latest 2>nul || echo Image already removed
                    docker rmi %SERVER_IMAGE%:%IMAGE_TAG% 2>nul || echo Image already removed
                    docker rmi %SERVER_IMAGE%:latest 2>nul || echo Image already removed
                """
            }
        }
    }
    
    post {
        always {
            bat 'docker logout'
        }
        success {
            echo '✅ Pipeline completed successfully!'
            echo "================================================"
            echo "Client Image: ${CLIENT_IMAGE}:${IMAGE_TAG}"
            echo "Server Image: ${SERVER_IMAGE}:${IMAGE_TAG}"
            echo "================================================"
            echo "Images are now available on Docker Hub!"
        }
        failure {
            echo '❌ Pipeline failed! Check the logs above.'
        }
    }
}
