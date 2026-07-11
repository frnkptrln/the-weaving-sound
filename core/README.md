# core

Small executable contracts shared by curated pieces. They provide a common
language without forcing every work into the same composition.

## Macro contract

macros.scd defines six normalized controls in the range 0..1:

brightness, density, motion, space, grit, tension

A piece owns the mapping from those perceptual controls to synthesis parameters.
Values outside the range are clipped at the contract boundary.

## Metadata contract

metadata.scd validates a piece description with these fields:

name, description, engines, tags, mode, duration, status

Status is one of active, study, or archived.
