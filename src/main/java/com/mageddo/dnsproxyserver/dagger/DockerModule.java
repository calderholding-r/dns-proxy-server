//package com.mageddo.dnsproxyserver.dagger;
//
//import com.github.dockerjava.api.DockerClient;
//import com.github.dockerjava.core.DefaultDockerClientConfig;
//import com.github.dockerjava.core.DockerClientImpl;
//import com.github.dockerjava.httpclient5.ApacheDockerHttpClient;
//import com.mageddo.dnsproxyserver.docker.DockerRepository;
//import com.mageddo.dnsproxyserver.docker.DockerRepositoryDefault;
//import dagger.Binds;
//import dagger.Module;
//
//import javax.enterprise.inject.Produces;
//import java.time.Duration;
//
//public interface DockerModule {
//
//  @Produces
//  DockerClient dockerClient() {
//    final var config = DefaultDockerClientConfig.createDefaultConfigBuilder()
//      .withDockerHost("unix:///var/run/docker.sock")
//      .withDockerTlsVerify(false)
////      .withDockerCertPath("/home/user/.docker")
////      .withRegistryUsername(registryUser)
////      .withRegistryPassword(registryPass)
////      .withRegistryEmail(registryMail)
////      .withRegistryUrl(registryUrl)
//      .build();
//
//    final var httpClient = new ApacheDockerHttpClient.Builder()
//      .dockerHost(config.getDockerHost())
//      .sslConfig(config.getSSLConfig())
//      .maxConnections(5)
//      .connectionTimeout(Duration.ofMillis(300))
//      .responseTimeout(Duration.ofSeconds(3))
//      .build();
//
//    return DockerClientImpl.getInstance(config, httpClient);
//  }
//
//
//}
