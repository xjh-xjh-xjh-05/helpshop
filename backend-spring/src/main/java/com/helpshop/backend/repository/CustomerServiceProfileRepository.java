package com.helpshop.backend.repository;

import com.helpshop.backend.entity.CustomerServiceProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CustomerServiceProfileRepository extends JpaRepository<CustomerServiceProfileEntity, String> {
    Optional<CustomerServiceProfileEntity> findByAccountId(String accountId);
}
