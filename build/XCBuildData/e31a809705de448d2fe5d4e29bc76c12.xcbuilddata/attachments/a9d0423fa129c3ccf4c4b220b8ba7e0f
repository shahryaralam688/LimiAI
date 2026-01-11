#!/bin/sh
#!/bin/sh
FRAMEWORK_RKC="${PLATFORM_DIR}/Developer/Library/Frameworks/RealityKit.framework/Resources/RealityKitContent.bundle"
DEST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/RealityKitContent.bundle"
if [ -d "$FRAMEWORK_RKC" ]; then
    rm -rf "${DEST}"
    cp -R "${FRAMEWORK_RKC}" "${DEST}"
fi

