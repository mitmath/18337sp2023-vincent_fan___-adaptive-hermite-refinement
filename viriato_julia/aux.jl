using .constants: nky, nkx, rhos, rhoi, small_rhoi, de, dz, three_D, pi
using .grid: gama0, ky

function omegakaw(bperp_max::Real)
    omega_kaw::Real
    omega_kaw_nl::Real
    kperp_dum::Real = 0.0
    first::Bool = true

    if first
        kperp_dum = sqrt(ky[nky÷2+1]^2 + (nkx*1.0)^2)
        first = false
    end

    if rhoi < small_rhoi
        omega_kaw = sqrt(1.0 + kperp_dum^2*(3.0/4.0*rhoi^2 + rhos^2)) * ky[nky÷2+1] * bperp_max / (1.0 + kperp_dum^2 * de^2)
        omega_kaw_nl = sqrt(1.0 + kperp_dum^2*(3.0/4.0*rhoi^2 + rhos^2)) * kperp_dum * bperp_max / (1.0 + kperp_dum^2 * de^2)
    else
        if three_D
            # omega_kaw = max(kperp_dum *
            #     sqrt(rhos^2 - rhoi^2 / (gama0(0.5*kperp_dum^2*rhoi^2)-1.)) *
            #     ky[nky÷2+1] * bperp_max / sqrt(1.0 + kperp_dum^2 * de^2),
            #     kperp_dum * sqrt(rhos^2 - 0.5*rhoi^2 / (gama0(0.5*kperp_dum^2*rhoi^2)-1.)) *
            #     2.0 * pi / (dz * sqrt(1.0 + kperp_dum^2 * de^2)))
            omega_kaw = kperp_dum *
                sqrt(rhos^2 - 0.5*rhoi^2 / (gama0(0.5*kperp_dum^2*rhoi^2)-1.)) *
                2.0 * pi / (dz * sqrt(1.0 + kperp_dum^2 * de^2))
        else
            omega_kaw = kperp_dum *
                sqrt(rhos^2 - rhoi^2 / (gama0(0.5*kperp_dum^2*rhoi^2)-1.)) *
                ky[nky÷2+1] * bperp_max / sqrt(1.0 + kperp_dum^2 * de^2)
        end
        omega_kaw_nl = kperp_dum^2 *
            sqrt(rhos^2 - rhoi^2 / (gama0(0.5*kperp_dum^2*rhoi^2)-1.)) *
            bperp_max / (1.0 + kperp_dum^2 * de^2)
    end

    return omega_kaw
end

using .grid: kperp, gama0
using .constants: rhoi, nky, nkx_par, nlz_par, small_rhoi, npe

#Note: @inbounds macro is used to eliminate bounds checking inside the loops for performance optimization.

function PHI_POT(nek::Array{ComplexF64,3}, phiK::Array{ComplexF64,3})
    @inbounds begin
        for j in 1:nky
            for i in 1:nkx_par
                for k in 1:nlz_par
                    phiK[i,j,k] = 0.0 + 0.0im
                end
            end
        end

        if (rhoi < small_rhoi)
            for i in 1:nkx_par
                for j in 1:nky
                    phiK[i,j,:] = -nek[i,j,:]/(kperp(i,j)^2)
                end
            end
        else
            for i in 1:nkx_par
                for j in 1:nky
                    phiK[i,j,:] = rhoi^2*0.5/(gama0(kperp(i,j)^2*rhoi^2*0.5)-1.0)*nek[i,j,:]
                end
            end
        end
    end
end

function SEMI_IMP_OP(dti::Real, bperp_max::Real, aa0::Real)
    SI_oper = Array{ComplexF64}(undef, nky, nkx_par, nlz_par)
    if (rhoi <= small_rhoi)then
        for i in 1:nkx_par
            for j in 1:nky
            SI_oper[i,j,:] = aa0^2*(1+kperp(i,j)^2*(3/4*rhoi^2+rhos^2))*
                            kperp(i,j)^2*bperp_max^2*
                            dti^2/(1.0+kperp(i,j)^2*de^2) 
            end
        end
    else
        for i in 1:nkx_par
            for j in 1:nky
                SI_oper[i,j,:] = aa0^2*(3*rhos^2-rhoi^2/(gama0(0.5*kperp(i,j)^2*rhoi^2)-1))*
                                kperp(i,j)^4*bperp_max^2*
                                dti^2/(1.0+kperp(i,j)^2*de^2) 
            end
        end
    end
    return SI_oper
end

function dtnext(relative_error::Real,x::Real,noinc:Bool,dti::Real)
    if noinc
        inc_fac = 1.0
        noinc = false # need to make noinc global
    else
        inc_fac = 1.08
    end

    if relative_error < 0.8*epsilon
        if x < inc_fac*dti
            dti = x
        else
            dti = inc_fac*dti
        end
    else
        dti = min(x,dti)
    end

    return dti
end