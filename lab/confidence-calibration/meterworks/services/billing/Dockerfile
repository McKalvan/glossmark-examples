FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY . .
RUN mvn -B -q package -DskipTests

FROM eclipse-temurin:21-jre
COPY --from=build /src/target/billing-*.jar /app/billing.jar
USER 10001
ENTRYPOINT ["java", "-jar", "/app/billing.jar"]
