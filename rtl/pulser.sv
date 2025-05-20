//-----------------------------------------------------------------------------------------------
// File        : pulser.sv
// Author      : Nico Canzani <ncanzani@student.ethz.ch>
// Description : Top-Level Wrapper for Multiple Pulse Generators
//
// This module integrates multiple instances of the `pulser_core` module and exposes a unified
// register interface over the OBI (Open Bus Interface) protocol.
//
// Key Features:
//   - Parameterizable number of pulser instances (`N_PULSER_INST`)
//   - Register-mapped control and configuration interface per pulser
//   - Instance selection and register decode via address bits
//   - Synchronous OBI protocol handshake handling (req, gnt, rvalid, etc.)
//   - Centralized command register for starting/stopping multiple pulsers simultaneously
//
// REGISTER MAP (per instance, offset by upper address bits):
//   - 0x00 : CMD         → Start/Stop pulses (bit-encoded per instance)
//   - 0x04 : F1_CFG      → {f1_end, f1_switch}
//   - 0x08 : F2_CFG      → {f2_end, f2_switch}
//   - 0x0C : COUNT_CFG   → {stop_count, f2_count, f1_count}
//   - 0x10 : STATUS      → {ready, state}
//   - 0x14 : OUT_CTRL    → {idle_out, invert_out}
//
// Each pulser is independently configurable and drives its own `pulse_o` output.
// The wrapper tracks FSM states and readiness status from each instance,
// and handles proper decoding, storage, and routing of configuration data.
//
// Dependencies:
//   - `pulser_core.sv` (pulser logic)
//   - `common_cells/registers.svh` (flip-flop and register macros)
//
// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//-----------------------------------------------------------------------------------------------

`include "register_interface/typedef.svh"

//-----------------------------------------------------------------------------------------------
// Top-level wrapper module for multiple pulser instances
//-----------------------------------------------------------------------------------------------
module pulser #(
  parameter obi_pkg::obi_cfg_t ObiCfg               = obi_pkg::ObiDefaultConfig,
  parameter type               obi_req_t            = logic,
  parameter type               obi_rsp_t            = logic,
  parameter type               reg_req_t            = logic,
  parameter type               reg_rsp_t            = logic,
  parameter int                N_PULSER_INST        = 4
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  output logic pulse_o
);

  logic [2:0]  state;
  logic        start_pulse, stop_pulse;

  reg_req_t reg_req;
  reg_rsp_t reg_rsp;

  pulser_reg_pkg::pulser_reg2hw_t reg2hw;
  pulser_reg_pkg::pulser_hw2reg_t hw2reg;

  periph_to_reg #(
    .AW        ( ObiCfg.AddrWidth ),
    .DW        ( ObiCfg.DataWidth ),
    .BW        ( 8 ),
    .IW        ( ObiCfg.IdWidth ),
    .req_t     ( reg_req_t ),
    .rsp_t     ( reg_rsp_t )
  ) i_periph_to_reg (
    .clk_i     ( clk_i ),
    .rst_ni    ( rst_ni ),

    .req_i     ( obi_req_i.req ),
    .add_i     ( obi_req_i.a.addr ),
    .wen_i     ( ~obi_req_i.a.we ),
    .wdata_i   ( obi_req_i.a.wdata ),
    .be_i      ( obi_req_i.a.be ),
    .id_i      ( obi_req_i.a.aid ),

    .gnt_o     ( obi_rsp_o.gnt ),
    .r_rdata_o ( obi_rsp_o.r.rdata ),
    .r_opc_o   (  ),  // ( obi_rsp_o.r.err ),
    .r_id_o    ( obi_rsp_o.r.rid ),
    .r_valid_o ( obi_rsp_o.rvalid ),

    .reg_req_o ( reg_req ),
    .reg_rsp_i ( reg_rsp )
  );

  pulser_reg_top #(
    .reg_req_t  ( reg_req_t ),
    .reg_rsp_t  ( reg_rsp_t )
  ) i_pulser_reg_top (
    .clk_i      ( clk_i ),
    .rst_ni     ( rst_ni ),
    .reg_req_i  ( reg_req ),
    .reg_rsp_o  ( reg_rsp ),
    // To HW
    .reg2hw     ( reg2hw ),
    .hw2reg     ( hw2reg ),

    // Config: If 1, explicit error return for unmapped register access
    .devmode_i  ( 1'b1 )
  );

  //-----------------------------------------------------------------------------------------------
  // Pulser instantiations
  //-----------------------------------------------------------------------------------------------

  assign start_pulse  = reg2hw.ctrl.start.qe & reg2hw.ctrl.start.q;
  assign stop_pulse   = reg2hw.ctrl.stop.qe & reg2hw.ctrl.stop.q;

  pulser_core i_pulser_core (
    .clk_i          ( clk_i ),
    .rst_ni         ( rst_ni ),
    .start_i        ( start_pulse ),
    .stop_i         ( stop_pulse ),
    .f1_cnt_i       ( reg2hw.count_cfg.f1.q ),
    .f2_cnt_i       ( reg2hw.count_cfg.f2.q ),
    .stop_cnt_i     ( reg2hw.count_cfg.count_stop.q ),
    .f1_end_i       ( reg2hw.f1_cfg.endval.q ),
    .f1_switch_i    ( reg2hw.f1_cfg.switchval.q ),
    .f2_end_i       ( reg2hw.f2_cfg.endval.q ),
    .f2_switch_i    ( reg2hw.f2_cfg.switchval.q ),
    .invert_out_i   ( reg2hw.out_ctrl.invert_out.q ),
    .idle_out_i     ( reg2hw.out_ctrl.idle_out.q ),
    .pulse_o        ( pulse_o ),
    .state_o        ( state )
  );

endmodule
