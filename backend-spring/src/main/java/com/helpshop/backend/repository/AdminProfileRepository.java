package com.helpshop.backend.repository;

import com.helpshop.backend.entity.AdminProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AdminProfileRepository extends JpaRepository<AdminProfileEntity, String> {
    Optional<AdminProfileEntity> findByAccountId(String accountId);
}
