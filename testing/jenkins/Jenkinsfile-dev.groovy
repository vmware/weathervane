// Will run on the agent with name or tag wvtest-AuctionDriver
node('wvtest-AuctionDriver') {
    try {
        // Perform routine maintenance tasks since AuctionDriver is a persistent VM
        stage('maintain driver') {
        // Remove unneeded docker images which take up lots of space on the AuctionDriver. These accumulate after each build.
        // docker rmi typically returns a code of 1 because it's unaable to delete some images.
        // Specifying '|| true' ignores the error code
        sh label: '', script: 'docker rmi $(docker images -q) || true'
        // may also need to zip, delete, or archive large/unnecessary run results files
        }

        stage('checkout') {
            // This is the 'checkout' function. 'git' function doesn't work because 'git' command doesn't support remote branches?
            checkout([$class: 'GitSCM', branches: [[name: 'origin/2.0.*-dev']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: 'https://github.com/vmware/weathervane']]])
        }
        stage('build') {
            // Build executables and images using DockerHub
            sh label: '', script: 'printf \'weathervane2\' | ./buildDockerImages.pl --username griderr  --proxy http://wdc-proxy.vmware.com:3128'
        }
        stage('test') {
            sh label: '', script: 'python3 /root/weathervane/testing/e2e/runE2eTests.py'
        }

    } catch (err) {
        notify("Error: ${err}")
        currentBuild.result = 'FAILURE'
    }
}

def notify(status){
    emailext (
      to: "griderr@vmware.com",
      subject: "${status}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
      body: """<p>${status}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
        <p>Check console output at <a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a></p>""",
    )
}
