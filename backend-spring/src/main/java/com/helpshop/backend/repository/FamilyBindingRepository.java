package com.helpshop.backend.repository;

import com.helpshop.backend.entity.FamilyBindingEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface FamilyBindingRepository extends JpaRepository<FamilyBindingEntity, String> {
    List<FamilyBindingEntity> findByChildAccountIdAndStatusOrderByCreatedAtDesc(String childAccountId, String status);
    List<FamilyBindingEntity> findByElderlyAccountIdAndStatus(String elderlyAccountId, String status);
    Optional<FamilyBindingEntity> findFirstByChildAccountIdAndStatusOrderByCreatedAtDesc(String childAccountId, String status);
    Optional<FamilyBindingEntity> findByElderlyAccountIdAndChildAccountIdAndStatus(String elderlyAccountId, String childAccountId, String status);
    Optional<FamilyBindingEntity> findFirstByStatusOrderByCreatedAtDesc(String status);
}
