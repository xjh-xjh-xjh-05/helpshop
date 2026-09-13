package com.helpshop.backend.repository;

import com.helpshop.backend.entity.AccountEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AccountRepository extends JpaRepository<AccountEntity, String> {
    Optional<AccountEntity> findByPhone(String phone);
}
