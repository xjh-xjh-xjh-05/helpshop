package com.helpshop.backend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.helpshop.backend.entity.AccountEntity;
import com.helpshop.backend.repository.AccountRepository;
import com.helpshop.backend.service.JwtTokenService;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtTokenService jwtTokenService;
    private final AccountRepository accountRepository;
    private final ObjectMapper objectMapper;

    public JwtAuthenticationFilter(JwtTokenService jwtTokenService,
                                   AccountRepository accountRepository,
                                   ObjectMapper objectMapper) {
        this.jwtTokenService = jwtTokenService;
        this.accountRepository = accountRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String token = jwtTokenService.resolveToken(request.getHeader("Authorization"));
        if (token == null || token.length() == 0) {
            filterChain.doFilter(request, response);
            return;
        }

        if (!jwtTokenService.isTokenValid(token)) {
            writeUnauthorized(response, "Invalid token");
            return;
        }

        String accountId = jwtTokenService.extractAccountId(token);
        AccountEntity account = accountRepository.findById(accountId).orElse(null);
        if (account == null) {
            writeUnauthorized(response, "Account unavailable");
            return;
        }

        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            List<SimpleGrantedAuthority> authorities = new ArrayList<SimpleGrantedAuthority>();
            if (account.defaultRole != null && account.defaultRole.length() > 0) {
                authorities.add(new SimpleGrantedAuthority("ROLE_" + account.defaultRole.toUpperCase()));
            }
            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(account.id, null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        filterChain.doFilter(request, response);
    }

    private void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        SecurityContextHolder.clearContext();
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        Map<String, Object> payload = new LinkedHashMap<String, Object>();
        payload.put("success", false);
        payload.put("message", message);
        objectMapper.writeValue(response.getWriter(), payload);
    }
}
