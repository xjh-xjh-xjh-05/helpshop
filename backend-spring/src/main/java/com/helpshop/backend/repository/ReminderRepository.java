package com.helpshop.backend.repository;

import com.helpshop.backend.entity.ReminderEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ReminderRepository extends JpaRepository<ReminderEntity, String> {
    List<ReminderEntity> findByElderlyAccountIdOrChildAccountIdOrderByCreatedAtDesc(String elderlyAccountId, String childAccountId);
    long countByElderlyAccountIdOrChildAccountId(String elderlyAccountId, String childAccountId);
}
