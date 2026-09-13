package com.helpshop.backend.repository;

import com.helpshop.backend.entity.ChildProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ChildProfileRepository extends JpaRepository<ChildProfileEntity, String> {
    Optional<ChildProfileEntity> findByAccountId(String accountId);
}
