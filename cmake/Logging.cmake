# ---------------------------------------------------------------
# Centralized log-level option. Translates the human-readable
# string into the integer that spdlog expects for SPDLOG_ACTIVE_LEVEL.
# ---------------------------------------------------------------

option(METAFFI_LOG_LEVEL "Minimum log level: TRACE/DEBUG/INFO/WARN/ERROR/OFF" "INFO")

if(METAFFI_LOG_LEVEL STREQUAL "TRACE")
    set(METAFFI_SPDLOG_LEVEL 0)
elseif(METAFFI_LOG_LEVEL STREQUAL "DEBUG")
    set(METAFFI_SPDLOG_LEVEL 1)
elseif(METAFFI_LOG_LEVEL STREQUAL "INFO")
    set(METAFFI_SPDLOG_LEVEL 2)
elseif(METAFFI_LOG_LEVEL STREQUAL "WARN")
    set(METAFFI_SPDLOG_LEVEL 3)
elseif(METAFFI_LOG_LEVEL STREQUAL "ERROR")
    set(METAFFI_SPDLOG_LEVEL 4)
elseif(METAFFI_LOG_LEVEL STREQUAL "OFF")
    set(METAFFI_SPDLOG_LEVEL 6)
else()
    message(FATAL_ERROR "Invalid METAFFI_LOG_LEVEL '${METAFFI_LOG_LEVEL}'. Use TRACE/DEBUG/INFO/WARN/ERROR/OFF")
endif()
