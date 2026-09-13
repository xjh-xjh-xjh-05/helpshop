package com.helpshop.backend.repository;

import com.helpshop.backend.entity.ElderlyProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ElderlyProfileRepository extends JpaRepository<ElderlyProfileEntity, String> {
    Optional<ElderlyProfileEntity> findByAccountId(String accountId);
}
