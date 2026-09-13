package com.helpshop.backend.service;

import com.helpshop.backend.entity.AccountEntity;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

@Service
public class JwtTokenService {
    @Value("${security.jwt.secret}")
    private String secret;

    @Value("${security.jwt.expiration-seconds:604800}")
    private long expirationSeconds;

    private Key signingKey;

    @PostConstruct
    public void init() {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateToken(AccountEntity account) {
        Date issuedAt = new Date();
        Date expiresAt = new Date(issuedAt.getTime() + expirationSeconds * 1000);
        return Jwts.builder()
                .setSubject(account.id)
                .claim("phone", account.phone)
                .claim("role", account.defaultRole)
                .claim("status", account.status)
                .setIssuedAt(issuedAt)
                .setExpiration(expiresAt)
                .signWith(signingKey, SignatureAlgorithm.HS256)
                .compact();
    }

    public String resolveToken(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            return null;
        }
        return authorization.substring("Bearer ".length()).trim();
    }

    public String extractAccountId(String token) {
        if (token == null || token.length() == 0) {
            return null;
        }
        return parseClaims(token).getSubject();
    }

    public boolean isTokenValid(String token) {
        if (token == null || token.length() == 0) {
            return false;
        }
        try {
            parseClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException ignored) {
            return false;
        }
    }

    private Claims parseClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(signingKey)
                .build()
                .parseClaimsJws(token)
                .getBody();
    }
}
