﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera1 : SceneViewFilter
{
    [SerializeField]
    private Shader _shader;

    public Material _raymarchMaterial
    {
        get
        {
            if (!_raymarchMat && _shader)
            {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return _raymarchMat;
        }
    }

    private Material _raymarchMat;

    public Camera _camera
    {
        get
        {
            if (!_cam)
            {
                _cam = GetComponent<Camera>();
            }
            return _cam;
        }
    }

    private Camera _cam;
    public float _maxDistance;

    [Range(1, 300)]
    public int _MaxIterations;
    [Range(0.1f, 0.001f)]
    public float _Accuracy;

    [Header("Light")]
    public Color _lightCol;
    public float _LightIntensity;


    [Header("shadow")]
    [Range(0, 4)]
    public float _ShadowIntensity;
    public Vector2 _ShadowDistance;
    [Range(1, 128)]
    public float _ShadowPenumbra;

    [Header("AO")]
    [Range(0.01f, 10.0f)]
    public float _AoStepsize;
    [Range(1, 5)]
    public int _AoIterations;
    [Range(0, 1)]
    public float _AoIntensity;

    [Header("Reflection")]
    [Range(0,2)]
    public int _ReflectionCount;
    [Range(0, 1)]
    public float _ReflectionIntensity;
    [Range(0, 1)]
    public float _EnReflIntensity;

    public Cubemap _ReflectionCube;


    [Header("Signed Distance Field")]

    public Vector4 _sphere;
    public float _sphereSmooth;
    public float _degreeRotate;

    [Header("Color")]
    public Color _GroundColor;
    public Gradient _SphereGradient;
    public Color[] _SphereColor = new Color[8];
    [Range(0,4)]
    public float _ColorIntensity;

    // public Vector3 _modInterval;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_raymarchMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }
  

        for (int i = 0; i < 8; i++)
        {
            _SphereColor[i] = _SphereGradient.Evaluate((1f / 8) * i);
        }

        _raymarchMaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMaterial.SetFloat("_maxDistance", _maxDistance);

        _raymarchMaterial.SetFloat("_ShadowIntensity", _ShadowIntensity);
        _raymarchMaterial.SetFloat("_ShadowPenumbra", _ShadowPenumbra);
        _raymarchMaterial.SetFloat("_LightIntensity", _LightIntensity);
        _raymarchMaterial.SetFloat("_Accuracy", _Accuracy);
        _raymarchMaterial.SetFloat("_AoStepsize", _AoStepsize);
        _raymarchMaterial.SetFloat("_AoIntensity", _AoIntensity);
        _raymarchMaterial.SetInt("_MaxIterations", _MaxIterations);
        _raymarchMaterial.SetInt("_AoIterations", _AoIterations);

        _raymarchMaterial.SetVector("_sphere",_sphere);
        _raymarchMaterial.SetFloat("_sphereSmooth", _sphereSmooth);
        _raymarchMaterial.SetFloat("_degreeRotate", _degreeRotate);


        _raymarchMaterial.SetVector("_ShadowDistance", _ShadowDistance);

        _raymarchMaterial.SetColor("_LightCol", _lightCol);


        //color
        _raymarchMaterial.SetColor("_GroundColor", _GroundColor);
        _raymarchMaterial.SetFloat("_ColorIntensity", _ColorIntensity);
        _raymarchMaterial.SetColorArray("_SphereColor", _SphereColor);


        //reflection
        _raymarchMaterial.SetInt("_ReflectionCount", _ReflectionCount);
        _raymarchMaterial.SetFloat("_ReflectionIntensity", _ReflectionIntensity);
        _raymarchMaterial.SetFloat("_EnReflIntensity", _EnReflIntensity);
        _raymarchMaterial.SetTexture("_ReflectionCube", _ReflectionCube);


        RenderTexture.active = destination;
        _raymarchMaterial.SetTexture("_MainTex", source);

       // Graphics.Blit(source, destination, _raymarchMaterial);
        
           GL.PushMatrix();
           GL.LoadOrtho();

           _raymarchMaterial.SetPass(0);
           GL.Begin(GL.QUADS);

           //BL
           GL.MultiTexCoord2(0, 0.0f, 0.0f);
           GL.Vertex3(0.0f, 0.0f, 3.0f);

           //BR
           GL.MultiTexCoord2(0, 1.0f, 0.0f);
           GL.Vertex3(1.0f, 0.0f, 2.0f);

           //TR
           GL.MultiTexCoord2(0, 1.0f, 1.0f);
           GL.Vertex3(1.0f, 1.0f, 1.0f);

           //TL
           GL.MultiTexCoord2(0, 0.0f, 1.0f);
           GL.Vertex3(0.0f, 1.0f, 0.0f);
           GL.End();
           



        GL.PopMatrix();

    }

    //返回一个矩阵，分别表示四个点的向量，在shader里插值后可以得到各像素点的方向
    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView*0.5f)*Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;
        
        
        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);

        //顺序为左上，右上，右下，左下。
        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);

        return frustum;
    }
}
