package com.helpshop.backend.repository;

import com.helpshop.backend.entity.AuditLogEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AuditLogRepository extends JpaRepository<AuditLogEntity, String> {
    List<AuditLogEntity> findByElderlyAccountIdOrActorAccountIdOrderByCreatedAtDesc(String elderlyAccountId, String actorAccountId);
}
